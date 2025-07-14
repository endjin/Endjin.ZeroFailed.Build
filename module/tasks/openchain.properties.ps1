# <copyright file="openchain.properties.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

# Synopsis: When true, the raw JSON-formatted Covenant SBOM will be uploaded to Azure blob storage
$PublishCovenantOutputToStorage = $true

# Synopsis: The Azure storage account used to store the Covenant SBOM
$AnalysisOutputStorageAccountName = property ZF_BUILD_OPENCHAIN_OUTPUT_STORAGE_ACCOUNT_NAME ""

# Synopsis: The Azure storage container used to store the Covenant SBOM
$AnalysisOutputContainerName = property ZF_BUILD_OPENCHAIN_OUTPUT_STORAGE_CONTAINER_NAME ""

# Synopsis: The Azure storage blob path used to store the Covenant SBOM
$AnalysisOutputBlobPath = property ZF_BUILD_OPENCHAIN_OUTPUT_STORAGE_BLOB_PATH ""

# Synopsis: When true, the licensing policy SBOM analysis step will be skipped
$SkipSbomAnalysis = [Convert]::ToBoolean((property ZF_BUILD_OPENCHAIN_SKIP_SBOM_ANALYSIS $false))