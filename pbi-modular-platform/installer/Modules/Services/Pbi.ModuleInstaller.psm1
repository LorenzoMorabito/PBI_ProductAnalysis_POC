function Get-PbiMappingOverrides {
    param([string]$MappingFile)

    if (-not $MappingFile) {
        return $null
    }

    return (Read-PbiJsonFile -Path $MappingFile)
}

function Resolve-PbiModuleMapping {
    param(
        [Parameter(Mandatory = $true)]$Module,
        [Parameter(Mandatory = $true)]$Project,
        $OverrideMapping
    )

    switch ($Module.Domain) {
        "finance" {
            return (Resolve-PbiFinanceModuleMapping -Manifest $Module.Manifest -OverrideMapping $OverrideMapping)
        }
        "marketing" {
            return (Resolve-PbiMarketingModuleMapping -Manifest $Module.Manifest -OverrideMapping $OverrideMapping)
        }
        default {
            throw "No mapping resolver is implemented for domain '$($Module.Domain)'."
        }
    }
}

function Test-PbiModuleAlreadyInstalled {
    param(
        [Parameter(Mandatory = $true)]$Project,
        [Parameter(Mandatory = $true)]$Module
    )

    $state = Get-PbiInstalledModulesState -Project $Project
    $record = Get-PbiInstalledModuleRecord -State $state -ModuleId $Module.ModuleId

    if ($record) {
        return $true
    }

    return ((Test-PbiSemanticAssetsPresent -Project $Project -Manifest $Module.Manifest) -and
        (Test-PbiReportAssetsPresent -Project $Project -Manifest $Module.Manifest))
}

function Invoke-PbiProjectValidation {
    param(
        [string]$WorkspaceRoot,
        [Parameter(Mandatory = $true)][string]$ProjectPath,
        [string]$Domain,
        [string]$ModuleId,
        [string]$MappingFile
    )

    $project = Resolve-PbiConsumerProject -ProjectPath $ProjectPath
    $modules = Get-PbiModuleList -WorkspaceRoot $WorkspaceRoot -Domain $Domain -ModuleId $ModuleId
    $overrideMapping = Get-PbiMappingOverrides -MappingFile $MappingFile
    $results = @()

    foreach ($module in $modules) {
        $validation = Test-PbiModuleRequirements -Project $project -Manifest $module.Manifest
        $mappings = Resolve-PbiModuleMapping -Module $module -Project $project -OverrideMapping $overrideMapping

        $results += [PSCustomObject]@{
            Domain          = $module.Domain
            ModuleId        = $module.ModuleId
            DisplayName     = $module.DisplayName
            Version         = $module.Version
            Installed       = (Test-PbiModuleAlreadyInstalled -Project $project -Module $module)
            IsValid         = $validation.IsValid
            MissingMeasures = (($validation.MissingMeasures | Sort-Object) -join ", ")
            MissingColumns  = (($validation.MissingColumns | Sort-Object) -join ", ")
            Mappings        = $mappings
        }
    }

    return $results
}

function Install-PbiModulePackage {
    param(
        [string]$WorkspaceRoot,
        [Parameter(Mandatory = $true)][string]$ProjectPath,
        [string]$Domain,
        [Parameter(Mandatory = $true)][string]$ModuleId,
        [string]$MappingFile,
        [switch]$ActivateInstalledPage,
        [switch]$Force
    )

    $project = Resolve-PbiConsumerProject -ProjectPath $ProjectPath
    $module = Get-PbiSingleModule -WorkspaceRoot $WorkspaceRoot -Domain $Domain -ModuleId $ModuleId
    $overrideMapping = Get-PbiMappingOverrides -MappingFile $MappingFile
    $mappings = Resolve-PbiModuleMapping -Module $module -Project $project -OverrideMapping $overrideMapping
    $validation = Test-PbiModuleRequirements -Project $project -Manifest $module.Manifest

    if (-not $validation.IsValid) {
        $missingMeasureText = ($validation.MissingMeasures | Sort-Object) -join ", "
        $missingColumnText = ($validation.MissingColumns | Sort-Object) -join ", "
        throw "Project '$($project.ProjectId)' is missing module requirements. Measures: [$missingMeasureText] Columns: [$missingColumnText]"
    }

    if ((Test-PbiModuleAlreadyInstalled -Project $project -Module $module) -and -not $Force) {
        throw "Module '$ModuleId' is already installed in project '$($project.ProjectId)'. Use -Force to reinstall."
    }

    Write-PbiInfo ("Installing module {0} into project {1}" -f $module.ModuleId, $project.ProjectId)
    Install-PbiSemanticAssets -Project $project -Module $module -Manifest $module.Manifest -Force:$Force
    Install-PbiReportAssets -Project $project -Module $module -Manifest $module.Manifest -ActivateInstalledPage:$ActivateInstalledPage -Force:$Force

    $state = Get-PbiInstalledModulesState -Project $project
    $existingModules = @($state.installedModules | Where-Object { $_.moduleId -ne $module.ModuleId })
    $existingModules += [ordered]@{
        moduleId         = $module.ModuleId
        version          = $module.Version
        source           = ($module.DomainRepoName + "/" + $module.PackageRelativePath)
        mappings         = $mappings
        installedObjects = [ordered]@{
            tables = @($module.Manifest.provides.semanticTables)
            page   = $module.Manifest.provides.reportPage.name
        }
        installedAt      = (Get-Date).ToString("s")
    }

    $state.installedModules = @($existingModules)
    Save-PbiInstalledModulesState -Project $project -State $state

    return [PSCustomObject]@{
        ProjectId      = $project.ProjectId
        ModuleId       = $module.ModuleId
        Version        = $module.Version
        SemanticTables = @($module.Manifest.provides.semanticTables)
        ReportPageName = $module.Manifest.provides.reportPage.name
        StateFilePath  = $project.StateFilePath
    }
}

Export-ModuleMember -Function Get-PbiMappingOverrides, Resolve-PbiModuleMapping, Invoke-PbiProjectValidation, Install-PbiModulePackage
