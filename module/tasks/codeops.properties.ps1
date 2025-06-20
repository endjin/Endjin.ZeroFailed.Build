# <copyright file="codeops.properties.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

# Synopsis: When true, the build will not report whether it is using the latest version of the core ZeroFailed module
$SkipZeroFailedModuleVersionCheck = $false

# Synopsis: When true, the build will not report whether the repo is using the latest version of the PR-AUTOFLOW GitHub Actions workflows
$SkipPrAutoflowVersionCheck = $false

# Synopsis: When true, the build will not report whether the repo is enrolled with PR-AUTOFLOW
$SkipPrAutoflowEnrollmentCheck = $false