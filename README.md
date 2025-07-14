# Endjin.ZeroFailed.Build

[![Build Status](https://github.com/endjin/Endjin.ZeroFailed.Build/actions/workflows/build.yml/badge.svg)](https://github.com/endjin/Endjin.ZeroFailed.Build/actions/workflows/build.yml)  
[![GitHub Release](https://img.shields.io/github/release/endjin/Endjin.ZeroFailed.Build.svg)](https://github.com/endjin/Endjin.ZeroFailed.Build/releases)  
[![PowerShell Gallery Version](https://img.shields.io/powershellgallery/v/Endjin.ZeroFailed.Build?color=blue)](https://www.powershellgallery.com/packages/Endjin.ZeroFailed.Build)  
[![License](https://img.shields.io/github/license/endjin/Endjin.ZeroFailed.Build.svg)](https://github.com/endjin/Endjin.ZeroFailed.Build/blob/main/LICENSE)

A [ZeroFailed](https://github.com/zerofailed/ZeroFailed) extension containing Endjin-specific build features as well acting as a 'meta' extension to bring in other standard dependencies.

## Overview

| Component Type | Included | Notes               |
|----------------|----------|---------------------|
| Tasks          | yes      | |
| Functions      | yes      | |
| Processes      | no       | Designed to be compatible with the default process provided by the [ZeroFailed.Build.Common](https://github.com/zerofailed/ZeroFailed.Build.Common) extension |

For more information about the different component types, please refer to the [ZeroFailed documentation](https://github.com/endjin/ZeroFailed/blob/main/README.md#extensions).

This extension consists of the following feature groups, click the links to see their documentation:

- CodeOps processes
- Software supply chain security

## Dependencies

| Extension                | Reference Type | Version |
|--------------------------|----------------|---------|
| [ZeroFailed.Build.DotNet](https://github.com/zerofailed/ZeroFailed.Build.DotNet) | git            | `main`  |
| [ZeroFailed.Build.GitHub](https://github.com/zerofailed/ZeroFailed.Build.GitHub) | git            | `main`  |

## Getting Started

If you are starting something new and don't yet have a ZeroFailed process setup, then follow the steps here to bootstrap your new project.

Once you have the above setup (or it you already have that), then simply add the following to your list of required extensions (e.g. in `config.ps1`):

```powershell
$zerofailedExtensions = @(
    ...
    # References the extension from its GitHub repository. If not already installed, use latest version from 'main' will be downloaded.
    @{
        Name = "Endjin.ZeroFailed.Build"
        GitRepository = "https://github.com/endjin/Endjin.ZeroFailed.Build"
        GitRef = "main"     # replace this with a Git Tag or SHA reference if want to pin to a specific version
    }

    # Alternatively, reference the extension from the PowerShell Gallery.
    @{
        Name = "Endjin.ZeroFailed.Build"
        Version = ""   # if no version is specified, the latest stable release will be used
    }
)
```

## Usage

For an example of using this extension to build a .NET project, please take a look at [this sample repo](https://github.com/endjin/Endjin.ZeroFailed.Sample.DotNet).

TODO: Python-based sample