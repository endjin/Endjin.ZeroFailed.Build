# <copyright file="openchain.tasks.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

# Synopsis: Stores the raw generated SBOM in an Azure storage account
task PublishCovenantOutputToStorage `
    -If { !$SkipBuildSolution -and $SolutionToBuild -and $PublishCovenantOutputToStorage } `
    -After RunCovenant `
    -Jobs {
    if ( (Test-Path $covenantJsonOutputFile) -and `
            $AnalysisOutputStorageAccountName -and `
            $AnalysisOutputContainerName -and `
            $AnalysisOutputBlobPath) {
    
        $covenantJsonOutputFilename = (Split-Path -Leaf $covenantJsonOutputFile)
        $filename = "{0}-{1}.json" -f [IO.Path]::GetFileNameWithoutExtension($covenantJsonOutputFilename),
                                     ([DateTime]::Now).ToString('yyyyMMddHHmmssfff')

        Write-Build White @"
Publishing storage account:
    Source File: $covenantJsonOutputFile
    Account: $AnalysisOutputStorageAccountName
    Blob Path: "$AnalysisOutputContainerName/$AnalysisOutputBlobPath/$filename"
"@

        $uri = "https://{0}.blob.core.windows.net/{1}/{2}/{3}" -f $AnalysisOutputStorageAccountName,
                        $AnalysisOutputContainerName,
                        $AnalysisOutputBlobPath,
                        $filename

        # Use basic retry logic to mitigate against transient failures
        $authUri = Invoke-CommandWithRetry -RetryCount 3 `
                                           -RetryDelay 10 `
                                           -Command {
                                                & az storage blob generate-sas `
                                                    --auth-mode login `
                                                    --as-user `
                                                    --https-only `
                                                    --account-name $AnalysisOutputStorageAccountName `
                                                    --blob-url $uri `
                                                    --permissions c `
                                                    --start (Get-Date).ToUniversalTime().ToString("yyyy-M-d'T'H:m'Z'") `
                                                    --expiry (Get-Date).AddMinutes(10).ToUniversalTime().ToString("yyyy-M-d'T'H:m'Z'") `
                                                    --full-uri `
                                                    -o tsv
                                            }
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Unable to generate a storage SAS token for publishing SBOM - have you run 'az login'?"
        }
        else {
            $headers = @{
                "x-ms-date" = [System.DateTime]::UtcNow.ToString("R")
                "x-ms-blob-type" = "BlockBlob"
            }
            # Use basic retry logic to mitigate against transient failures
            Invoke-CommandWithRetry -RetryCount 3 `
                                    -RetryDelay 10 `
                                    -Command {
                                        Invoke-RestMethod -Headers $headers `
                                                            -Uri $authUri `
                                                            -Method PUT `
                                                            -InFile $covenantJsonOutputFile `
                                                            -Verbose:$false | Out-Null
                                    }
    
            Write-Build Green "Covenant JSON output published to storage account"
        }
    }
    else {
        Write-Build White "Publishing of Covenant output skipped, due to absent configuration"
    }
}

# Synopsis: Generates CSV files containing summarised SBOM details for the current build
task RunSBOMAnalysis `
    -If { !$SkipBuildSolution -and $SolutionToBuild -and $env:SBOM_ANALYSIS_RELEASE_READER_PAT } `
    -Jobs EnsureGitHubCli,PublishCovenantOutputToStorage,{
    if (!(Get-InstalledPSResource Az.Storage)){
        # Use basic retry logic to mitigate against transient issues with the PowerShell Gallery
        Invoke-CommandWithRetry -RetryCount 3 `
                                -RetryDelay 10 `
                                -Command { Install-PSResource Az.Storage -Scope CurrentUser -Repository PSGallery -Force -Verbose }
    }
    
    $AnalysisOutputContainerName = "data"
    $AnalysisOutputStorageAccountName = "endsynapsedatalake"
    # 1. Download JSON ruleset 
    $uri = "https://{0}.blob.core.windows.net/{1}/{2}/{3}" -f $AnalysisOutputStorageAccountName,
                        $AnalysisOutputContainerName,
                        "openchain/license_rules",
                        "license_rule_set.json"
    $isAuthenticated = $false
    try{
        # Use basic retry logic to mitigate against transient failures
        $authUri = Invoke-CommandWithRetry -RetryCount 3 `
                                           -RetryDelay 10 `
                                           -Command {
                                                        exec { & az storage blob generate-sas `
                                                                --auth-mode login `
                                                                --as-user `
                                                                --https-only `
                                                                --account-name $AnalysisOutputStorageAccountName `
                                                                --blob-url $uri `
                                                                --permissions re `
                                                                --start (Get-Date).ToUniversalTime().ToString("yyyy-M-d'T'H:m'Z'") `
                                                                --expiry (Get-Date).AddMinutes(10).ToUniversalTime().ToString("yyyy-M-d'T'H:m'Z'") `
                                                                --full-uri `
                                                                -o tsv
                                                        }
                                                    }
        $isAuthenticated = $true
    }
    catch{
        Write-Warning "Skipping SBOM Analysis, unable to access the license rule set. Ensure you are logged into the Azure CLI"
    }
    if($isAuthenticated){
        Write-Host $authUri
        $analysisFilesLocation = '.analysis'
        if(!(Test-Path $analysisFilesLocation)){
            New-Item -ItemType Directory $analysisFilesLocation | Out-Null
        }
        Get-AzStorageBlobContent -Destination "$($analysisFilesLocation)/" -absoluteuri $authUri -Force | fl 

        # Switch to a PAT that gives read access to the repo hosting the analysis tool
        $savedGhToken = $env:GH_TOKEN
        $env:GH_TOKEN = $env:SBOM_ANALYSIS_RELEASE_READER_PAT
        try {
            # Find latest version released on GitHub - use basic retry logic to mitigate against transient failures
            $latestVersion = Invoke-CommandWithRetry -Command { exec { gh release list -R endjin/endjin-sbom-analyser --limit 1 } } `
                                                     -RetryCount 3 `
                                                     -RetryDelay 10 |
                ConvertFrom-Csv -Header title,type,"tag name",published -Delimiter `t |
                Select-Object -ExpandProperty "tag name"
        }
        finally {
            $env:GH_TOKEN = $savedGhToken
        }
        
        if (!$latestVersion) {
            throw "Unable to determine the latest version of the Python tool"
        }
        Write-Host $latestVersion

        $DownloadFileName = "sbom_analyser-$($latestVersion)-py3-none-any.whl"
        if(!(Test-Path (Join-Path $analysisFilesLocation $DownloadFileName))){
            Write-Host "Downloading latest release of SBOM Analyser, version" $latestVersion
            # Use basic retry logic to mitigate against transient failures
            Invoke-CommandWithRetry -Command { exec { & gh release download -R "endjin/endjin-sbom-analyser" -p $DownloadFileName -D $analysisFilesLocation} } `
                                    -RetryCount 3 `
                                    -RetryDelay 10
        }
        
        exec {
            pip install poetry
            pip install (Join-Path $analysisFilesLocation $DownloadFileName)
        }
        $sbomPath = $covenantJsonOutputFile
        Write-Host $sbomPath
        $jsonPath = Get-ChildItem -path "$($analysisFilesLocation)/openchain/license_rules/*.json"
        Write-Host $jsonPath
        
        Push-Location $analysisFilesLocation
        try{
            exec{
                generate_sbom_score $sbomPath $jsonPath
            }
            $summarisedContent = Get-Content 'sbom_analysis_summarised_scores.csv' | ConvertFrom-Csv

            if ($summarisedContent.Unknown -gt 0){ 
                Write-Warning (Write-SBOMComponents -fileName 'sbom_analysis_unknown_components.csv' -sum $summarisedContent.Unknown -type 'unknown')
            }
            if ($summarisedContent.Rejected -gt 0){
                throw Write-SBOMComponents -fileName 'sbom_analysis_rejected_components.csv' -sum $summarisedContent.Rejected -type 'rejected'
            }
        }
        finally{
            Pop-Location
        }
    }
}
