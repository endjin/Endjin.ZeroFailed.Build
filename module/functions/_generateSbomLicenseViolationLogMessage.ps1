# <copyright file="_generateSbomLicenseViolationLogMessage.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
  Generates a summary log message with license type violation details.

.DESCRIPTION
  Generates a summary log message with license type violation details, using the outout from the SBOM Analyser tool.

.PARAMETER FileName
  Path to the .csv file produced by the SBOM Analyser tool.

.PARAMETER Sum
  The count of the type of violations to be summarised.

.PARAMETER Type
  The type of violations to be summarised.

.EXAMPLE
  _generateSbomLicenseViolationLogMessage 
#>
function _generateSbomLicenseViolationLogMessage {
    [CmdletBinding()]
    param (
        $FileName,
        $Sum,
        $Type
    )

    $components = Import-Csv $FileName | Select-Object -Property name, license
    $componentsHashtable = @{}
    $components | ForEach-Object {
        if($_.License -eq ""){
            $componentsHashtable[$_.Name] = "Unspecified"
        }
        else{
            $componentsHashtable[$_.Name] = $_.License
        }
    }
    $componentsString = ""
    foreach ($row in $componentsHashtable.GetEnumerator()){
        $componentsString += "$($row.Name) : $($row.Value)`n"
    }

    $content = "There are $($Sum) $($Type) components in this build, please review the $($FileName) and make appropriate changes `n$($componentsString)"
    return $content
}
