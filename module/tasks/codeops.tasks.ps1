# <copyright file="codeops.tasks.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

# Synopsis: Checks whether the latest version of the ZeroFailed module is being used
task CheckLatestZeroFailedVersion -If { !$SkipZeroFailedModuleVersionCheck } -After InitCore {
    $currentVersion = (Get-Module ZeroFailed).Version
    # Use basic retry logic to mitigate against transient issues with the PowerShell Gallery
    [version]$latestVersion = Invoke-CommandWithRetry -Command { (Find-PSResource ZeroFailed -Type Module -Repository PSGallery).Version } -RetryCount 3 -RetryDelay 10
    if ($currentVersion -lt $latestVersion) {
        $msg = @"
A newer ZeroFailed version is available: $latestVersion
An overnight CodeOps process should automatically update this, alternatively, you can manually update by changing the default value of the '`$BuildModuleVersion' parameter in this build script to be '$latestVersion'
"@
        Write-Warning $msg
    }
    else {
        Write-Build Green "ZeroFailed is up-to-date"
    }
}

# Synopsis: Checks whether the latest version of the PR-AUTOFLOW GitHub Actions workflows are being used
task CheckPrAutoflowVersion -If { !$SkipPrAutoflowVersionCheck -and $script:repoIsEnrolledWithPrAutoflow } -After InitCore EnsureGitHubCli,{

    $sourceRepo = "endjin/endjin-codeops"
    $sourceRepoPath = "repo-level-processes/pr-autoflow/workflow-templates"
    $workflowsToCheck = @(
        "auto_release.yml"
        "dependabot_approve_and_label.yml"
    )

    $allWorkflowsUpToDate = $true
    foreach ($workflow in $workflowsToCheck) {
        $resp = $null
        # Use basic retry logic to mitigate against transient issues
        Invoke-CommandWithRetry -Command { exec { & gh api "repos/$sourceRepo/contents/$sourceRepoPath/$workflow" } } `
                                -RetryCount 3 `
                                -RetryDelay 10 |
            ConvertFrom-Json -Depth 100 |
            Tee-Object -Variable resp
        $latestWorkflow = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String(($resp).content))
        if ($IsWindows) {
            # Convert the linux line-endings so we can compare it to our local file
            $latestWorkflow = $latestWorkflow -replace "`n","`r`n"
        }
        $currentWorkflow = Get-Content -Raw $here/.github/workflows/$workflow
        if (Compare-Object $latestWorkflow $currentWorkflow -CaseSensitive) {
            $allWorkflowsUpToDate = $false
            Write-Warning "Out-dated workflow: $workflow"
        }
    }

    if ($allWorkflowsUpToDate) {
        Write-Build Green "All 'pr-autoflow' workflows are up-to-date"
    }
    else {
        Write-Warning "Out-of-date workflows can be updated (for all repos) by triggering this workflow: https://github.com/endjin/endjin-codeops/actions/workflows/deploy_pr_autoflow.yml"
    }
}

# Synopsis: Checks whether the repo is enrolled with PR-AUTOFLOW
task CheckPrAutoflowEnrollment -If { !$SkipPrAutoflowEnrollmentCheck } -After InitCore EnsureGitHubCli,{

    # Ensure the YAML parsing module is installed
    if (!(Get-Module -ListAvailable powershell-yaml)) {
        Write-Host "Installing required module: powershell-yaml"
        Install-PSResource powershell-yaml -Scope CurrentUser -Force -Repository PSGallery -RequiredVersion 0.4.12
    }

    # Workaround for powershell-yaml bug whereby it overwrites the '$here' variable in the calling scope
    $here_backup = $here
    Import-Module powershell-yaml
    $script:here = $here_backup

    # This is where we maintain the configuration that enrolls repos with the process that keeps them up-to-date
    # with the pr-autoflow GitHub Actions workflows
    $sourceRepo = "endjin/endjin-codeops"
    $sourceRepoPath = "repo-level-processes/config/live"

    $repoDetails = $null
    try {
        # Use basic retry logic to mitigate against transient failures
        Invoke-CommandWithRetry -Command { exec { & gh repo view --json owner,name } } `
                                -RetryCount 3 `
                                -RetryDelay 10 |
            ConvertFrom-Json |
            Tee-Object -Variable repoDetails
        $orgName = $repoDetails.owner.login
        $repoName = $repoDetails.name
    
        $resp = $null
        # Use basic retry logic to mitigate against transient failures
        Invoke-CommandWithRetry -Command { exec { & gh api "repos/$sourceRepo/contents/$sourceRepoPath/$orgName.yml" } } `
                                -RetryCount 3 `
                                -RetryDelay 10 |
            ConvertFrom-Json -Depth 100 |
            Tee-Object -Variable resp
        $config = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String(($resp).content))
        $enrollment = $config | ConvertFrom-Yaml | ? { $repoName -in $_.repos.name -and $_.repos.ContainsKey("prAutoflowSettings") }
        $script:repoIsEnrolledWithPrAutoflow = $enrollment -ne $null
        if (!$repoIsEnrolledWithPrAutoflow) {
            Write-Warning "Repository not enrolled with 'pr-autoflow' - refer to https://github.com/endjin/endjin-codeops/blob/main/README.md#enrollment for how to enroll this repository."
        }
        else {
            Write-Build Green "Repository is enrolled with 'pr-autoflow'"
        }
    }
    catch {
        Write-Build Yellow "Repo could not be found on GitHub so cannot be enrolled with pr-autoflow"
    }
}
