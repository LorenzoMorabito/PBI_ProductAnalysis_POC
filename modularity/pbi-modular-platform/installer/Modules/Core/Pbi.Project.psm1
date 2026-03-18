function Resolve-PbiConsumerProject {
    param([Parameter(Mandatory = $true)][string]$ProjectPath)

    $resolvedProjectPath = (Resolve-Path $ProjectPath).Path
    $projectItem = Get-Item $resolvedProjectPath

    if ($projectItem.PSIsContainer) {
        $pbipFiles = @(Get-ChildItem -Path $projectItem.FullName -Filter "*.pbip")

        if ($pbipFiles.Count -ne 1) {
            throw "Project folder '$resolvedProjectPath' must contain exactly one .pbip file."
        }

        $pbipPath = $pbipFiles[0].FullName
    }
    elseif ($projectItem.Extension -eq ".pbip") {
        $pbipPath = $projectItem.FullName
    }
    else {
        throw "ProjectPath must be a .pbip file or a folder containing a single .pbip file."
    }

    $projectRoot = Split-Path $pbipPath -Parent
    $pbip = Read-PbiJsonFile -Path $pbipPath
    $reportArtifact = $pbip.artifacts | Where-Object { $_.report } | Select-Object -First 1

    if (-not $reportArtifact) {
        throw "PBIP '$pbipPath' does not contain a report artifact."
    }

    $reportPath = Resolve-PbiPath -BasePath $projectRoot -RelativePath $reportArtifact.report.path
    $pbirPath = Join-Path $reportPath "definition.pbir"
    $pbir = Read-PbiJsonFile -Path $pbirPath

    if (-not $pbir.datasetReference.byPath.path) {
        throw "PBIR '$pbirPath' does not contain a datasetReference.byPath.path."
    }

    $semanticModelPath = Resolve-PbiPath -BasePath $reportPath -RelativePath $pbir.datasetReference.byPath.path
    $projectId = [System.IO.Path]::GetFileNameWithoutExtension($pbipPath)
    $moduleConfigDir = Join-Path $projectRoot ("module-config\" + $projectId)

    return [PSCustomObject]@{
        ProjectId         = $projectId
        ProjectRoot       = $projectRoot
        PbipPath          = $pbipPath
        ReportPath        = $reportPath
        SemanticModelPath = $semanticModelPath
        ModuleConfigDir   = $moduleConfigDir
        StateFilePath     = Join-Path $moduleConfigDir "installed-modules.json"
        LogsRoot          = Join-Path $moduleConfigDir "logs"
        DiffRoot          = Join-Path $moduleConfigDir "diffs"
        SnapshotsRoot     = Join-Path $moduleConfigDir "snapshots"
    }
}

function New-PbiInstalledModulesStateSkeleton {
    return [ordered]@{
        schemaVersion   = "2.0.0"
        generatedAt     = Get-PbiUtcTimestamp
        installedModules = @()
    }
}

function Get-PbiProjectModelPath {
    param([Parameter(Mandatory = $true)]$Project)
    return (Join-Path $Project.SemanticModelPath "definition/model.tmdl")
}

function Get-PbiProjectPagesMetadataPath {
    param([Parameter(Mandatory = $true)]$Project)
    return (Join-Path $Project.ReportPath "definition/pages/pages.json")
}

function Get-PbiProjectTablePath {
    param(
        [Parameter(Mandatory = $true)]$Project,
        [Parameter(Mandatory = $true)][string]$TableName
    )

    return (Join-Path $Project.SemanticModelPath ("definition/tables/" + $TableName + ".tmdl"))
}

function Get-PbiMeasureNamesFromProjectTmdl {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path $Path)) {
        return @()
    }

    $content = Get-Content -Path $Path -Raw
    $pattern = "(?m)^\s*measure\s+(?:'((?:[^']|'')+)'|([A-Za-z_][A-Za-z0-9_]*))(?=\s*=|\s*$)"
    $matches = [regex]::Matches($content, $pattern)
    $measureNames = New-Object System.Collections.Generic.List[string]

    foreach ($match in $matches) {
        if ($match.Groups[1].Success) {
            $measureNames.Add($match.Groups[1].Value.Replace("''", "'"))
        }
        elseif ($match.Groups[2].Success) {
            $measureNames.Add($match.Groups[2].Value)
        }
    }

    return @($measureNames | Select-Object -Unique)
}

function Get-PbiModulePageFilesFromProject {
    param(
        [Parameter(Mandatory = $true)]$Project,
        [string]$PageName
    )

    if ([string]::IsNullOrWhiteSpace($PageName)) {
        return @()
    }

    $pageRoot = Join-Path $Project.ReportPath ("definition/pages/" + $PageName)
    if (-not (Test-Path $pageRoot)) {
        return @()
    }

    return @(
        Get-ChildItem -Path $pageRoot -Recurse -File -ErrorAction SilentlyContinue |
            ForEach-Object { Get-PbiRelativePath -BasePath $Project.ProjectRoot -Path $_.FullName }
    )
}

function Get-PbiDerivedFilesTouchedForRecord {
    param(
        [Parameter(Mandatory = $true)]$Project,
        [Parameter(Mandatory = $true)]$Record
    )

    $paths = New-Object System.Collections.Generic.List[string]
    $paths.Add((Get-PbiRelativePath -BasePath $Project.ProjectRoot -Path $Project.StateFilePath))

    foreach ($tableName in @($Record.installedObjects.tables)) {
        $tablePath = Get-PbiProjectTablePath -Project $Project -TableName $tableName
        $paths.Add((Get-PbiRelativePath -BasePath $Project.ProjectRoot -Path $tablePath))
    }

    if (-not [string]::IsNullOrWhiteSpace($Record.installedObjects.page)) {
        $paths.Add((Get-PbiRelativePath -BasePath $Project.ProjectRoot -Path (Get-PbiProjectPagesMetadataPath -Project $Project)))
        foreach ($pageFile in (Get-PbiModulePageFilesFromProject -Project $Project -PageName $Record.installedObjects.page)) {
            $paths.Add($pageFile)
        }
    }

    $paths.Add((Get-PbiRelativePath -BasePath $Project.ProjectRoot -Path (Get-PbiProjectModelPath -Project $Project)))
    return @($paths | Sort-Object -Unique)
}

function Get-PbiDerivedSemanticObjectsForRecord {
    param(
        [Parameter(Mandatory = $true)]$Project,
        [Parameter(Mandatory = $true)]$Record
    )

    $measureNames = New-Object System.Collections.Generic.List[string]
    foreach ($tableName in @($Record.installedObjects.tables)) {
        foreach ($measureName in (Get-PbiMeasureNamesFromProjectTmdl -Path (Get-PbiProjectTablePath -Project $Project -TableName $tableName))) {
            $measureNames.Add($measureName)
        }
    }

    return [ordered]@{
        tables   = @($Record.installedObjects.tables)
        measures = @($measureNames | Sort-Object -Unique)
    }
}

function Get-PbiDerivedReportObjectsForRecord {
    param(
        [Parameter(Mandatory = $true)]$Project,
        [Parameter(Mandatory = $true)]$Record
    )

    $pageFiles = Get-PbiModulePageFilesFromProject -Project $Project -PageName $Record.installedObjects.page
    $pageRoot = if ([string]::IsNullOrWhiteSpace($Record.installedObjects.page)) {
        $null
    }
    else {
        Join-Path $Project.ReportPath ("definition/pages/" + $Record.installedObjects.page)
    }

    $visualCount = 0
    if ($pageRoot -and (Test-Path $pageRoot)) {
        $visualCount = @(
            Get-ChildItem -Path $pageRoot -Recurse -File -Filter "visual.json" -ErrorAction SilentlyContinue
        ).Count
    }

    return [ordered]@{
        page        = if ($Record.installedObjects.page) { $Record.installedObjects.page } else { "" }
        files       = @($pageFiles)
        visualCount = [int]$visualCount
    }
}

function Get-PbiExistingFilesSizeBytes {
    param(
        [Parameter(Mandatory = $true)]$Project,
        [Parameter(Mandatory = $true)][string[]]$RelativePaths
    )

    $total = 0L
    foreach ($relativePath in @($RelativePaths | Sort-Object -Unique)) {
        $absolutePath = Join-Path $Project.ProjectRoot $relativePath
        if (Test-Path $absolutePath -PathType Leaf) {
            $total += [int64](Get-PbiPathSizeBytes -Path $absolutePath)
        }
    }

    return $total
}

function Test-PbiRecordField {
    param(
        [Parameter(Mandatory = $true)]$Record,
        [Parameter(Mandatory = $true)][string]$Name
    )

    if ($Record -is [System.Collections.IDictionary]) {
        return $Record.Contains($Name)
    }

    return ($Record.PSObject.Properties.Name -contains $Name)
}

function Get-PbiRecordFieldValue {
    param(
        [Parameter(Mandatory = $true)]$Record,
        [Parameter(Mandatory = $true)][string]$Name,
        $DefaultValue = $null
    )

    if ($Record -is [System.Collections.IDictionary]) {
        if ($Record.Contains($Name)) {
            return $Record[$Name]
        }

        return $DefaultValue
    }

    if ($Record.PSObject.Properties.Name -contains $Name) {
        return $Record.$Name
    }

    return $DefaultValue
}

function ConvertTo-PbiOrderedMap {
    param($InputObject)

    $map = [ordered]@{}
    if ($null -eq $InputObject) {
        return $map
    }

    if ($InputObject -is [System.Collections.IDictionary]) {
        foreach ($key in $InputObject.Keys) {
            $map[[string]$key] = $InputObject[$key]
        }

        return $map
    }

    foreach ($property in $InputObject.PSObject.Properties) {
        $map[$property.Name] = $property.Value
    }

    return $map
}

function ConvertTo-PbiManagedInstalledModuleRecord {
    param(
        [Parameter(Mandatory = $true)]$Project,
        [Parameter(Mandatory = $true)]$Record
    )

    $tables = @()
    if ($Record.installedObjects -and $Record.installedObjects.tables) {
        $tables = @($Record.installedObjects.tables)
    }

    $pageName = ""
    if ($Record.installedObjects -and $Record.installedObjects.page) {
        $pageName = [string]$Record.installedObjects.page
    }

    $installedAtValue = if ((Test-PbiRecordField -Record $Record -Name "installedAt") -and $Record.installedAt) { $Record.installedAt } else { Get-PbiUtcTimestamp }
    if ($installedAtValue -is [datetime]) {
        $installedAtValue = $installedAtValue.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    }

    $managedRecord = [ordered]@{
        moduleId            = $Record.moduleId
        version             = $Record.version
        domain              = if (Test-PbiRecordField -Record $Record -Name "domain") { $Record.domain } else { "" }
        type                = if (Test-PbiRecordField -Record $Record -Name "type") { $Record.type } elseif ($tables.Count -gt 0) { "semantic" } else { "report-only" }
        classification      = if (Test-PbiRecordField -Record $Record -Name "classification") { $Record.classification } elseif ($tables.Count -gt 0) { "semantic-light" } else { "report-only" }
        semanticImpact      = if (Test-PbiRecordField -Record $Record -Name "semanticImpact") { $Record.semanticImpact } elseif ($tables.Count -gt 0) { "additive" } else { "none" }
        source              = $Record.source
        mappings            = if ($Record.mappings) { $Record.mappings } else { [ordered]@{} }
        installedAt         = [string]$installedAtValue
        lastAction          = if ((Test-PbiRecordField -Record $Record -Name "lastAction") -and $Record.lastAction) { $Record.lastAction } else { "legacy-install" }
        installedObjects    = [ordered]@{
            tables = @($tables)
            page   = $pageName
        }
    }

    $managedRecord["filesTouched"] = if ((Test-PbiRecordField -Record $Record -Name "filesTouched") -and @($Record.filesTouched).Count -gt 0) {
        @($Record.filesTouched | Sort-Object -Unique)
    }
    else {
        @(Get-PbiDerivedFilesTouchedForRecord -Project $Project -Record $managedRecord)
    }

    $managedRecord["semanticObjectsAdded"] = if (Test-PbiRecordField -Record $Record -Name "semanticObjectsAdded") {
        $Record.semanticObjectsAdded
    }
    else {
        Get-PbiDerivedSemanticObjectsForRecord -Project $Project -Record $managedRecord
    }

    $managedRecord["reportObjectsAdded"] = if (Test-PbiRecordField -Record $Record -Name "reportObjectsAdded") {
        $Record.reportObjectsAdded
    }
    else {
        Get-PbiDerivedReportObjectsForRecord -Project $Project -Record $managedRecord
    }

    $managedRecord["impactMetrics"] = if (Test-PbiRecordField -Record $Record -Name "impactMetrics") {
        $Record.impactMetrics
    }
    else {
        [ordered]@{
            fileCount          = @($managedRecord.filesTouched).Count
            sizeDeltaBytes     = [int](Get-PbiExistingFilesSizeBytes -Project $Project -RelativePaths @($managedRecord.filesTouched))
            semanticTableCount = @($managedRecord.semanticObjectsAdded.tables).Count
            semanticMeasureCount = @($managedRecord.semanticObjectsAdded.measures).Count
            reportFileCount    = @($managedRecord.reportObjectsAdded.files).Count
            reportVisualCount  = [int]$managedRecord.reportObjectsAdded.visualCount
        }
    }

    $managedRecord["history"] = ConvertTo-PbiOrderedMap -InputObject (Get-PbiRecordFieldValue -Record $Record -Name "history" -DefaultValue ([ordered]@{}))
    $managedRecord["governance"] = ConvertTo-PbiOrderedMap -InputObject (Get-PbiRecordFieldValue -Record $Record -Name "governance" -DefaultValue ([ordered]@{ status = "UNKNOWN"; reasons = @() }))
    return $managedRecord
}

function ConvertTo-PbiManagedInstalledModulesState {
    param(
        [Parameter(Mandatory = $true)]$Project,
        $State
    )

    $normalizedState = New-PbiInstalledModulesStateSkeleton

    if ($null -eq $State) {
        return $normalizedState
    }

    foreach ($record in @($State.installedModules)) {
        $normalizedState.installedModules += @(ConvertTo-PbiManagedInstalledModuleRecord -Project $Project -Record $record)
    }

    return $normalizedState
}

function Get-PbiInstalledModulesState {
    param([Parameter(Mandatory = $true)]$Project)

    if (-not (Test-Path $Project.StateFilePath)) {
        return (New-PbiInstalledModulesStateSkeleton)
    }

    $state = Read-PbiJsonFile -Path $Project.StateFilePath
    $normalizedState = ConvertTo-PbiManagedInstalledModulesState -Project $Project -State $state
    Test-PbiInstalledModulesStateSchema -State $normalizedState -StatePath $Project.StateFilePath
    return $normalizedState
}

function Save-PbiInstalledModulesState {
    param(
        [Parameter(Mandatory = $true)]$Project,
        [Parameter(Mandatory = $true)]$State
    )

    Ensure-PbiDirectory -Path $Project.ModuleConfigDir
    $normalizedState = ConvertTo-PbiManagedInstalledModulesState -Project $Project -State $State
    $normalizedState.generatedAt = Get-PbiUtcTimestamp
    Test-PbiInstalledModulesStateSchema -State $normalizedState -StatePath $Project.StateFilePath
    Write-PbiJsonFile -Path $Project.StateFilePath -InputObject $normalizedState
}

function Get-PbiInstalledModuleRecord {
    param(
        [Parameter(Mandatory = $true)]$State,
        [Parameter(Mandatory = $true)][string]$ModuleId
    )

    return @($State.installedModules | Where-Object { $_.moduleId -eq $ModuleId } | Select-Object -First 1)
}

function Set-PbiInstalledModuleRecord {
    param(
        [Parameter(Mandatory = $true)]$State,
        [Parameter(Mandatory = $true)]$Record
    )

    $existingModules = @($State.installedModules | Where-Object { $_.moduleId -ne $Record.moduleId })
    $existingModules += $Record
    $State.installedModules = @($existingModules | Sort-Object moduleId)
    return $State
}

function Remove-PbiInstalledModuleRecord {
    param(
        [Parameter(Mandatory = $true)]$State,
        [Parameter(Mandatory = $true)][string]$ModuleId
    )

    $State.installedModules = @($State.installedModules | Where-Object { $_.moduleId -ne $ModuleId })
    return $State
}

Export-ModuleMember -Function Resolve-PbiConsumerProject, New-PbiInstalledModulesStateSkeleton, Get-PbiInstalledModulesState, Save-PbiInstalledModulesState, Get-PbiInstalledModuleRecord, Set-PbiInstalledModuleRecord, Remove-PbiInstalledModuleRecord
