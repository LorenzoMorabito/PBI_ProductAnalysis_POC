function Test-PbiModuleManifest {
    param(
        [Parameter(Mandatory = $true)]$Manifest,
        [Parameter(Mandatory = $true)][string]$ManifestPath
    )

    $requiredProperties = @("moduleId", "version", "domain", "description", "requires", "provides")

    foreach ($propertyName in $requiredProperties) {
        if (-not $Manifest.PSObject.Properties.Name.Contains($propertyName)) {
            throw "Manifest $ManifestPath is missing required property '$propertyName'."
        }
    }
}

function Get-PbiModuleList {
    param(
        [string]$WorkspaceRoot,
        [string]$Domain,
        [string]$ModuleId
    )

    $resolvedWorkspaceRoot = Get-PbiInstallerWorkspaceRoot -WorkspaceRoot $WorkspaceRoot -ScriptRoot $PSScriptRoot
    $domainRoots = Get-ChildItem -Path $resolvedWorkspaceRoot -Directory -Filter "pbi-*-domain"
    $modules = @()

    foreach ($domainRoot in $domainRoots) {
        $catalogPath = Join-Path $domainRoot.FullName "catalog/modules.json"

        if (-not (Test-Path $catalogPath)) {
            continue
        }

        $catalog = Read-PbiJsonFile -Path $catalogPath

        foreach ($package in $catalog.packages) {
            $packageRoot = Resolve-PbiPath -BasePath $domainRoot.FullName -RelativePath $package.path
            $manifestPath = Join-Path $packageRoot "manifest.json"
            $manifest = Read-PbiJsonFile -Path $manifestPath
            Test-PbiModuleManifest -Manifest $manifest -ManifestPath $manifestPath

            $moduleRecord = [PSCustomObject]@{
                Domain                = $catalog.domain
                DomainRoot            = $domainRoot.FullName
                DomainRepoName        = $domainRoot.Name
                CatalogPath           = $catalogPath
                ModuleId              = $manifest.moduleId
                DisplayName           = $package.displayName
                Version               = $manifest.version
                Status                = $manifest.status
                PackageRoot           = $packageRoot
                PackageRelativePath   = $package.path
                ManifestPath          = $manifestPath
                Manifest              = $manifest
                ConsumerCompatibility = @($package.consumerCompatibility)
            }

            $modules += $moduleRecord
        }
    }

    if ($Domain) {
        $modules = $modules | Where-Object { $_.Domain -eq $Domain }
    }

    if ($ModuleId) {
        $modules = $modules | Where-Object { $_.ModuleId -eq $ModuleId }
    }

    return @($modules | Sort-Object Domain, ModuleId)
}

function Get-PbiSingleModule {
    param(
        [string]$WorkspaceRoot,
        [string]$Domain,
        [Parameter(Mandatory = $true)][string]$ModuleId
    )

    $modules = Get-PbiModuleList -WorkspaceRoot $WorkspaceRoot -Domain $Domain -ModuleId $ModuleId

    if (-not $modules) {
        throw "Module '$ModuleId' was not found."
    }

    if ($modules.Count -gt 1) {
        throw "Module '$ModuleId' is ambiguous. Specify the domain explicitly."
    }

    return $modules[0]
}

Export-ModuleMember -Function Test-PbiModuleManifest, Get-PbiModuleList, Get-PbiSingleModule
