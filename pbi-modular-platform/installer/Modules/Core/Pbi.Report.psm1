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

function Test-PbiReportAssetsPresent {
    param(
        [Parameter(Mandatory = $true)]$Project,
        [Parameter(Mandatory = $true)]$Manifest
    )

    if (-not $Manifest.provides.reportPage) {
        return $false
    }

    $pagePath = Get-PbiPageDestinationRoot -Project $Project -PageName $Manifest.provides.reportPage.name
    return (Test-Path $pagePath)
}

function Install-PbiReportAssets {
    param(
        [Parameter(Mandatory = $true)]$Project,
        [Parameter(Mandatory = $true)]$Module,
        [Parameter(Mandatory = $true)]$Manifest,
        [switch]$ActivateInstalledPage,
        [switch]$Force
    )

    if (-not $Manifest.provides.reportPage) {
        return
    }

    $pageName = $Manifest.provides.reportPage.name
    $sourceReportPath = Join-Path $Module.PackageRoot "report"
    $destinationPagePath = Get-PbiPageDestinationRoot -Project $Project -PageName $pageName

    if ((Test-Path $destinationPagePath) -and -not $Force) {
        throw "Report page '$pageName' already exists at '$destinationPagePath'. Use -Force to overwrite."
    }

    Ensure-PbiDirectory -Path $destinationPagePath
    Copy-Item -Path (Join-Path $sourceReportPath "*") -Destination $destinationPagePath -Recurse -Force

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
}

Export-ModuleMember -Function Test-PbiReportAssetsPresent, Install-PbiReportAssets
