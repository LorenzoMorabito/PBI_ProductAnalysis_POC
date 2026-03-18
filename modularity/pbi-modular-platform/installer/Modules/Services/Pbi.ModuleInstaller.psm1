function Get-PbiMappingOverrides {
    param([string]$MappingFile)

    if (-not $MappingFile) {
        return $null
    }

    return (Read-PbiJsonFile -Path $MappingFile)
}

function Merge-PbiModuleMappings {
    param(
        $BaseMapping,
        $OverrideMapping
    )

    if (-not $BaseMapping) {
        return $OverrideMapping
    }

    if (-not $OverrideMapping) {
        return $BaseMapping
    }

    $merged = [ordered]@{}

    foreach ($sectionName in @("coreMeasures", "coreColumns")) {
        $merged[$sectionName] = [ordered]@{}

        if ($BaseMapping.$sectionName) {
            foreach ($property in $BaseMapping.$sectionName.PSObject.Properties) {
                $merged[$sectionName][$property.Name] = $property.Value
            }
        }

        if ($OverrideMapping.$sectionName) {
            foreach ($property in $OverrideMapping.$sectionName.PSObject.Properties) {
                $merged[$sectionName][$property.Name] = $property.Value
            }
        }
    }

    return $merged
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
        $semanticPresent = Test-PbiSemanticAssetsPresent -Project $Project -Manifest $Module.Manifest
        $reportPresent = Test-PbiReportAssetsPresent -Project $Project -Manifest $Module.Manifest
        return ($semanticPresent -and $reportPresent)
    }

    return $false
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
        $measureConflicts = Test-PbiModuleMeasureConflicts -Project $project -Module $module -Manifest $module.Manifest
        $mappings = Resolve-PbiModuleMapping -Module $module -Project $project -OverrideMapping $overrideMapping

        $results += [PSCustomObject]@{
            Domain            = $module.Domain
            ModuleId          = $module.ModuleId
            DisplayName       = $module.DisplayName
            Version           = $module.Version
            Type              = $module.Type
            Classification    = $module.Classification
            SemanticImpact    = $module.SemanticImpact
            Installed         = (Test-PbiModuleAlreadyInstalled -Project $project -Module $module)
            IsValid           = ($validation.IsValid -and -not $measureConflicts.HasConflicts)
            MissingMeasures   = (($validation.MissingMeasures | Sort-Object) -join ", ")
            MissingColumns    = (($validation.MissingColumns | Sort-Object) -join ", ")
            MeasureConflicts  = (($measureConflicts.Conflicts | Sort-Object) -join ", ")
            Mappings          = $mappings
        }
    }

    return $results
}

function Get-PbiDefaultInstalledModuleImpactMetrics {
    param(
        [Parameter(Mandatory = $true)]$Project,
        [Parameter(Mandatory = $true)][string[]]$FilesTouched,
        [Parameter(Mandatory = $true)]$SemanticObjectsAdded,
        [Parameter(Mandatory = $true)]$ReportObjectsAdded
    )

    $sizeBytes = 0L
    foreach ($relativePath in @($FilesTouched | Sort-Object -Unique)) {
        $absolutePath = Join-Path $Project.ProjectRoot $relativePath
        if (Test-Path $absolutePath -PathType Leaf) {
            $sizeBytes += [int64](Get-PbiPathSizeBytes -Path $absolutePath)
        }
    }

    return [ordered]@{
        fileCount            = [int]@($FilesTouched).Count
        sizeDeltaBytes       = [int64]$sizeBytes
        semanticTableCount   = [int]@($SemanticObjectsAdded.tables).Count
        semanticMeasureCount = [int]@($SemanticObjectsAdded.measures).Count
        reportFileCount      = [int]@($ReportObjectsAdded.files).Count
        reportVisualCount    = [int]$ReportObjectsAdded.visualCount
    }
}

function Install-PbiModulePackage {
    param(
        [string]$WorkspaceRoot,
        [Parameter(Mandatory = $true)][string]$ProjectPath,
        [string]$Domain,
        [Parameter(Mandatory = $true)][string]$ModuleId,
        [string]$MappingFile,
        $ResolvedMappings,
        $OperationMetadata,
        [switch]$ActivateInstalledPage,
        [switch]$Force
    )

    $project = Resolve-PbiConsumerProject -ProjectPath $ProjectPath
    $module = Get-PbiSingleModule -WorkspaceRoot $WorkspaceRoot -Domain $Domain -ModuleId $ModuleId
    $overrideMapping = if ($PSBoundParameters.ContainsKey("ResolvedMappings") -and $null -ne $ResolvedMappings) {
        $ResolvedMappings
    }
    else {
        $mappingOverride = Get-PbiMappingOverrides -MappingFile $MappingFile
        Resolve-PbiModuleMapping -Module $module -Project $project -OverrideMapping $mappingOverride
    }

    $validation = Test-PbiModuleRequirements -Project $project -Manifest $module.Manifest
    $measureConflicts = Test-PbiModuleMeasureConflicts -Project $project -Module $module -Manifest $module.Manifest
    $state = Get-PbiInstalledModulesState -Project $project
    $existingRecord = Get-PbiInstalledModuleRecord -State $state -ModuleId $module.ModuleId

    if (-not $validation.IsValid) {
        $missingMeasureText = ($validation.MissingMeasures | Sort-Object) -join ", "
        $missingColumnText = ($validation.MissingColumns | Sort-Object) -join ", "
        throw "Project '$($project.ProjectId)' is missing module requirements. Measures: [$missingMeasureText] Columns: [$missingColumnText]"
    }

    if ($measureConflicts.HasConflicts) {
        throw "Project '$($project.ProjectId)' already contains measure names required by module '$ModuleId': [$($measureConflicts.Conflicts -join ", ")]"
    }

    if ($existingRecord -and -not $Force) {
        if ($existingRecord.version -eq $module.Version) {
            if (Test-PbiModuleAlreadyInstalled -Project $project -Module $module) {
                return [PSCustomObject]@{
                    Project      = $project
                    Module       = $module
                    StateRecord  = $existingRecord
                    NoOp         = $true
                    Action       = "no-op"
                    LogPath      = if ($OperationMetadata -and $OperationMetadata.logPath) { $OperationMetadata.logPath } else { $null }
                }
            }
        }
        else {
            throw "Module '$ModuleId' is already installed at version '$($existingRecord.version)' in project '$($project.ProjectId)'. Use upgrade-module."
        }
    }

    Write-PbiInfo ("Applying module {0} {1} into project {2}" -f $module.ModuleId, $module.Version, $project.ProjectId)
    $semanticInstall = Install-PbiSemanticAssets -Project $project -Module $module -Manifest $module.Manifest -Force:$Force
    $reportInstall = Install-PbiReportAssets -Project $project -Module $module -Manifest $module.Manifest -ActivateInstalledPage:$ActivateInstalledPage -Force:$Force

    $filesTouched = @(
        @($semanticInstall.FilesTouched) +
        @($reportInstall.FilesTouched) +
        @(Get-PbiRelativePath -BasePath $project.ProjectRoot -Path $project.StateFilePath)
    ) | Sort-Object -Unique

    $semanticObjectsAdded = if ($semanticInstall.SemanticObjectsAdded) { $semanticInstall.SemanticObjectsAdded } else { [ordered]@{ tables = @(); measures = @() } }
    $reportObjectsAdded = if ($reportInstall.ReportObjectsAdded) { $reportInstall.ReportObjectsAdded } else { [ordered]@{ page = ""; files = @(); visualCount = 0 } }

    $record = [ordered]@{
        moduleId            = $module.ModuleId
        version             = $module.Version
        domain              = $module.Domain
        type                = $module.Type
        classification      = $module.Classification
        semanticImpact      = $module.SemanticImpact
        source              = ($module.DomainRepoName + "/" + $module.PackageRelativePath)
        mappings            = $overrideMapping
        installedAt         = if ($OperationMetadata -and $OperationMetadata.installedAt) { $OperationMetadata.installedAt } else { Get-PbiUtcTimestamp }
        lastAction          = if ($OperationMetadata -and $OperationMetadata.action) { $OperationMetadata.action } else { "install" }
        filesTouched        = @($filesTouched)
        semanticObjectsAdded = $semanticObjectsAdded
        reportObjectsAdded  = $reportObjectsAdded
        installedObjects    = [ordered]@{
            tables = @($module.Manifest.provides.semanticTables)
            page   = if ($module.Manifest.provides.reportPage) { $module.Manifest.provides.reportPage.name } else { "" }
        }
        impactMetrics       = if ($OperationMetadata -and $OperationMetadata.impactMetrics) {
            $OperationMetadata.impactMetrics
        }
        else {
            Get-PbiDefaultInstalledModuleImpactMetrics -Project $project -FilesTouched @($filesTouched) -SemanticObjectsAdded $semanticObjectsAdded -ReportObjectsAdded $reportObjectsAdded
        }
        history             = if ($OperationMetadata -and $OperationMetadata.history) { $OperationMetadata.history } else { [ordered]@{} }
        governance          = if ($OperationMetadata -and $OperationMetadata.governance) { $OperationMetadata.governance } else { [ordered]@{ status = "UNKNOWN"; reasons = @() } }
    }

    $state = Set-PbiInstalledModuleRecord -State $state -Record $record
    Save-PbiInstalledModulesState -Project $project -State $state

    return [PSCustomObject]@{
        Project        = $project
        Module         = $module
        StateRecord    = $record
        NoOp           = $false
        Action         = $record.lastAction
        SemanticTables = @($record.semanticObjectsAdded.tables)
        ReportPageName = $record.reportObjectsAdded.page
        StateFilePath  = $project.StateFilePath
        LogPath        = if ($OperationMetadata -and $OperationMetadata.logPath) { $OperationMetadata.logPath } else { $null }
    }
}

Export-ModuleMember -Function Get-PbiMappingOverrides, Merge-PbiModuleMappings, Resolve-PbiModuleMapping, Test-PbiModuleAlreadyInstalled, Invoke-PbiProjectValidation, Install-PbiModulePackage
