function Get-PbiPagesMetadataPath {
    param([Parameter(Mandatory = $true)]$Project)

    return (Join-Path $Project.ReportPath "definition/pages/pages.json")
}

function Get-PbiPageDestinationRoot {
    param(
        [Parameter(Mandatory = $true)]$Project,
        [Parameter(Mandatory = $true)][string]$PageName
    )

    return (Join-Path $Project.ReportPath ("definition/pages/" + $PageName))
}

function Get-PbiModuleReportFileMappings {
    param(
        [Parameter(Mandatory = $true)]$Project,
        [Parameter(Mandatory = $true)]$Module,
        [Parameter(Mandatory = $true)]$Manifest,
        $ResolvedMappings
    )

    if (-not $Manifest.provides.reportPage) {
        return @()
    }

    $renderedMappings = @(Get-PbiRenderedModuleReportAssets -Project $Project -Module $Module -Manifest $Manifest -ResolvedMappings $ResolvedMappings)
    if ($renderedMappings.Count -gt 0) {
        return $renderedMappings
    }

    $sourceReportPath = Join-Path $Module.PackageRoot "report"
    $destinationPagePath = Get-PbiPageDestinationRoot -Project $Project -PageName $Manifest.provides.reportPage.name
    $mappings = New-Object System.Collections.Generic.List[object]

    foreach ($sourceFile in (Get-ChildItem -Path $sourceReportPath -Recurse -File -ErrorAction SilentlyContinue)) {
        $relativeFilePath = (Get-PbiRelativePath -BasePath $sourceReportPath -Path $sourceFile.FullName).Replace("/", "\")
        $destinationFilePath = Join-Path $destinationPagePath $relativeFilePath
        $mappings.Add([PSCustomObject]@{
            SourcePath      = $sourceFile.FullName
            DestinationPath = $destinationFilePath
            RelativePath    = (Get-PbiRelativePath -BasePath $Project.ProjectRoot -Path $destinationFilePath)
        })
    }

    return $mappings.ToArray()
}

function Get-PbiModuleReportObjectSummary {
    param(
        [Parameter(Mandatory = $true)]$Project,
        [Parameter(Mandatory = $true)]$Module,
        [Parameter(Mandatory = $true)]$Manifest,
        $ResolvedMappings
    )

    if (-not $Manifest.provides.reportPage) {
        return [ordered]@{
            page        = ""
            files       = @()
            visualCount = 0
        }
    }

    $fileMappings = Get-PbiModuleReportFileMappings -Project $Project -Module $Module -Manifest $Manifest -ResolvedMappings $ResolvedMappings
    $visualCount = @($fileMappings | Where-Object { [System.IO.Path]::GetFileName($_.SourcePath) -eq "visual.json" }).Count

    return [ordered]@{
        page        = $Manifest.provides.reportPage.name
        files       = @($fileMappings | Select-Object -ExpandProperty RelativePath | Sort-Object -Unique)
        visualCount = [int]$visualCount
    }
}

function Test-PbiReportAssetsPresent {
    param(
        [Parameter(Mandatory = $true)]$Project,
        [Parameter(Mandatory = $true)]$Manifest
    )

    if (-not $Manifest.provides.reportPage) {
        return $true
    }

    $pagePath = Get-PbiPageDestinationRoot -Project $Project -PageName $Manifest.provides.reportPage.name
    return (Test-Path $pagePath)
}

function Install-PbiReportAssets {
    param(
        [Parameter(Mandatory = $true)]$Project,
        [Parameter(Mandatory = $true)]$Module,
        [Parameter(Mandatory = $true)]$Manifest,
        $ResolvedMappings,
        [switch]$ActivateInstalledPage,
        [switch]$Force
    )

    if (-not $Manifest.provides.reportPage) {
        return [PSCustomObject]@{
            FilesTouched        = @()
            ReportObjectsAdded  = [ordered]@{
                page        = ""
                files       = @()
                visualCount = 0
            }
        }
    }

    $pageName = $Manifest.provides.reportPage.name
    $destinationPagePath = Get-PbiPageDestinationRoot -Project $Project -PageName $pageName
    $fileMappings = @(Get-PbiModuleReportFileMappings -Project $Project -Module $Module -Manifest $Manifest -ResolvedMappings $ResolvedMappings)

    if ((Test-Path $destinationPagePath) -and -not $Force) {
        throw "Report page '$pageName' already exists at '$destinationPagePath'. Use -Force to overwrite."
    }

    if ((Test-Path $destinationPagePath) -and $Force) {
        Remove-Item -Path $destinationPagePath -Recurse -Force
    }

    Ensure-PbiDirectory -Path $destinationPagePath
    foreach ($mapping in $fileMappings) {
        $renderedContent = if ($mapping.SourceContent) {
            [string]$mapping.SourceContent
        }
        else {
            $sourceContent = Get-Content -Path $mapping.SourcePath -Raw
            Convert-PbiTextWithResolvedMappings -Text $sourceContent -ResolvedMappings $ResolvedMappings
        }

        Write-PbiUtf8File -Path $mapping.DestinationPath -Content $renderedContent
    }

    $pagesMetadataPath = Get-PbiPagesMetadataPath -Project $Project
    $pagesMetadata = Read-PbiJsonFile -Path $pagesMetadataPath
    $pageOrder = @($pagesMetadata.pageOrder)

    if ($pageOrder -notcontains $pageName) {
        $pageOrder += $pageName
    }

    $pagesMetadata.pageOrder = $pageOrder

    if ($ActivateInstalledPage -or -not $pagesMetadata.activePageName) {
        $pagesMetadata.activePageName = $pageName
    }

    Write-PbiJsonFile -Path $pagesMetadataPath -InputObject $pagesMetadata

    $filesTouched = New-Object System.Collections.Generic.List[string]
    foreach ($pageFile in (Get-ChildItem -Path $destinationPagePath -Recurse -File -ErrorAction SilentlyContinue)) {
        $filesTouched.Add((Get-PbiRelativePath -BasePath $Project.ProjectRoot -Path $pageFile.FullName))
    }
    $filesTouched.Add((Get-PbiRelativePath -BasePath $Project.ProjectRoot -Path $pagesMetadataPath))

    return [PSCustomObject]@{
        FilesTouched       = @($filesTouched | Sort-Object -Unique)
        ReportObjectsAdded = (Get-PbiModuleReportObjectSummary -Project $Project -Module $Module -Manifest $Manifest -ResolvedMappings $ResolvedMappings)
    }
}

Export-ModuleMember -Function Get-PbiPagesMetadataPath, Get-PbiPageDestinationRoot, Test-PbiReportAssetsPresent, Get-PbiModuleReportFileMappings, Get-PbiModuleReportObjectSummary, Install-PbiReportAssets
