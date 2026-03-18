Set-StrictMode -Version Latest

function Get-PbiPageRootRelativePath {
    param(
        [Parameter(Mandatory = $true)]$Project,
        [string]$PageName
    )

    if ([string]::IsNullOrWhiteSpace($PageName)) {
        return $null
    }

    $pageRoot = Join-Path $Project.ReportPath ("definition/pages/" + $PageName)
    return (Get-PbiRelativePath -BasePath $Project.ProjectRoot -Path $pageRoot)
}

function Get-PbiModuleSnapshotPlan {
    param(
        [Parameter(Mandatory = $true)]$Project,
        [Parameter(Mandatory = $true)]$Module,
        $StateRecord
    )

    $filePaths = New-Object System.Collections.Generic.List[string]
    $cleanupRoots = New-Object System.Collections.Generic.List[string]
    $filePaths.Add((Get-PbiRelativePath -BasePath $Project.ProjectRoot -Path $Project.StateFilePath))

    $currentTables = @(
        if ($StateRecord) {
            $StateRecord.installedObjects.tables
        }
    )
    $targetTables = @($Module.Manifest.provides.semanticTables)
    if (($currentTables.Count -gt 0) -or ($targetTables.Count -gt 0)) {
        $filePaths.Add((Get-PbiRelativePath -BasePath $Project.ProjectRoot -Path (Get-PbiModelPath -Project $Project)))
    }

    foreach ($tableName in @($currentTables + $targetTables | Sort-Object -Unique)) {
        $filePaths.Add((Get-PbiRelativePath -BasePath $Project.ProjectRoot -Path (Get-PbiTableDefinitionPath -Project $Project -TableName $tableName)))
    }

    $currentPage = if ($StateRecord) { $StateRecord.installedObjects.page } else { "" }
    $targetPage = if ($Module.Manifest.provides.reportPage) { $Module.Manifest.provides.reportPage.name } else { "" }
    if ((-not [string]::IsNullOrWhiteSpace($currentPage)) -or (-not [string]::IsNullOrWhiteSpace($targetPage))) {
        $filePaths.Add((Get-PbiRelativePath -BasePath $Project.ProjectRoot -Path (Get-PbiPagesMetadataPath -Project $Project)))
    }

    foreach ($cleanupRoot in @(
            (Get-PbiPageRootRelativePath -Project $Project -PageName $currentPage),
            (Get-PbiPageRootRelativePath -Project $Project -PageName $targetPage)
        ) | Where-Object { $_ }) {
        $cleanupRoots.Add($cleanupRoot)
    }

    if ($StateRecord -and $StateRecord.reportObjectsAdded -and @($StateRecord.reportObjectsAdded.files).Count -gt 0) {
        foreach ($relativePath in @($StateRecord.reportObjectsAdded.files)) {
            $filePaths.Add($relativePath)
        }
    }

    foreach ($mapping in (Get-PbiModuleReportFileMappings -Project $Project -Module $Module -Manifest $Module.Manifest)) {
        $filePaths.Add($mapping.RelativePath)
    }

    return [ordered]@{
        filePaths    = @($filePaths | Sort-Object -Unique)
        cleanupRoots = @($cleanupRoots | Sort-Object -Unique)
    }
}

function New-PbiModuleSnapshot {
    param(
        [Parameter(Mandatory = $true)]$Project,
        [Parameter(Mandatory = $true)][string]$ModuleId,
        [Parameter(Mandatory = $true)][string]$Action,
        [Parameter(Mandatory = $true)]$SnapshotPlan,
        [string]$FromVersion,
        [string]$ToVersion
    )

    $snapshotId = Get-PbiTimestampKey
    $snapshotRoot = Join-Path (Join-Path $Project.SnapshotsRoot $ModuleId) $snapshotId
    $contentRoot = Join-Path $snapshotRoot "content"
    Ensure-PbiDirectory -Path $contentRoot

    $entries = New-Object System.Collections.Generic.List[object]
    foreach ($relativePath in @($SnapshotPlan.filePaths)) {
        $absolutePath = Join-Path $Project.ProjectRoot $relativePath
        $entry = [ordered]@{
            relativePath       = $relativePath
            existedBefore      = $false
            sizeBytes          = 0
            backupRelativePath = $relativePath
        }

        if (Test-Path $absolutePath -PathType Leaf) {
            $entry.existedBefore = $true
            $entry.sizeBytes = [int64](Get-PbiPathSizeBytes -Path $absolutePath)
            $backupPath = Join-Path $contentRoot $relativePath
            $backupParent = Split-Path $backupPath -Parent
            Ensure-PbiDirectory -Path $backupParent
            Copy-Item -Path $absolutePath -Destination $backupPath -Force
        }

        $entries.Add($entry)
    }

    $metadata = [ordered]@{
        snapshotId   = $snapshotId
        moduleId     = $ModuleId
        projectId    = $Project.ProjectId
        action       = $Action
        createdAt    = Get-PbiUtcTimestamp
        fromVersion  = $FromVersion
        toVersion    = $ToVersion
        cleanupRoots = @($SnapshotPlan.cleanupRoots)
        files        = $entries.ToArray()
    }

    Write-PbiJsonFile -Path (Join-Path $snapshotRoot "metadata.json") -InputObject $metadata
    return [PSCustomObject]@{
        snapshotId   = $snapshotId
        snapshotRoot = $snapshotRoot
        metadataPath = Join-Path $snapshotRoot "metadata.json"
        metadata     = $metadata
    }
}

function Get-PbiModuleSnapshot {
    param(
        [Parameter(Mandatory = $true)]$Project,
        [Parameter(Mandatory = $true)][string]$ModuleId,
        [Parameter(Mandatory = $true)][string]$SnapshotId
    )

    $snapshotRoot = Join-Path (Join-Path $Project.SnapshotsRoot $ModuleId) $SnapshotId
    $metadataPath = Join-Path $snapshotRoot "metadata.json"

    if (-not (Test-Path $metadataPath)) {
        throw "Snapshot '$SnapshotId' for module '$ModuleId' was not found."
    }

    return [PSCustomObject]@{
        snapshotId   = $SnapshotId
        snapshotRoot = $snapshotRoot
        metadataPath = $metadataPath
        metadata     = Read-PbiJsonFile -Path $metadataPath
    }
}

function Get-PbiLatestModuleSnapshot {
    param(
        [Parameter(Mandatory = $true)]$Project,
        [Parameter(Mandatory = $true)][string]$ModuleId
    )

    $moduleSnapshotRoot = Join-Path $Project.SnapshotsRoot $ModuleId
    if (-not (Test-Path $moduleSnapshotRoot)) {
        return $null
    }

    $latestSnapshotDir = Get-ChildItem -Path $moduleSnapshotRoot -Directory -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending |
        Select-Object -First 1

    if (-not $latestSnapshotDir) {
        return $null
    }

    return (Get-PbiModuleSnapshot -Project $Project -ModuleId $ModuleId -SnapshotId $latestSnapshotDir.Name)
}

function Restore-PbiModuleSnapshot {
    param(
        [Parameter(Mandatory = $true)]$Project,
        [Parameter(Mandatory = $true)]$Snapshot
    )

    foreach ($cleanupRoot in @($Snapshot.metadata.cleanupRoots | Sort-Object Length -Descending)) {
        $absoluteCleanupRoot = Join-Path $Project.ProjectRoot $cleanupRoot
        if (Test-Path $absoluteCleanupRoot) {
            Remove-Item -Path $absoluteCleanupRoot -Recurse -Force
        }
    }

    foreach ($entry in @($Snapshot.metadata.files)) {
        $absolutePath = Join-Path $Project.ProjectRoot $entry.relativePath
        if (Test-Path $absolutePath -PathType Leaf) {
            Remove-Item -Path $absolutePath -Force
        }
    }

    foreach ($entry in @($Snapshot.metadata.files)) {
        if (-not $entry.existedBefore) {
            continue
        }

        $destinationPath = Join-Path $Project.ProjectRoot $entry.relativePath
        $sourcePath = Join-Path (Join-Path $Snapshot.snapshotRoot "content") $entry.backupRelativePath
        $destinationParent = Split-Path $destinationPath -Parent
        Ensure-PbiDirectory -Path $destinationParent
        Copy-Item -Path $sourcePath -Destination $destinationPath -Force
    }
}

function Remove-PbiTablesFromModel {
    param(
        [Parameter(Mandatory = $true)]$Project,
        [Parameter(Mandatory = $true)][string[]]$TableNames
    )

    if (@($TableNames).Count -eq 0) {
        return
    }

    $modelPath = Get-PbiModelPath -Project $Project
    $content = Get-Content -Path $modelPath -Raw
    $match = [regex]::Match($content, "annotation PBI_QueryOrder = (\[.*?\])", [System.Text.RegularExpressions.RegexOptions]::Singleline)

    if ($match.Success) {
        $currentOrder = @(ConvertFrom-PbiJsonText -Text $match.Groups[1].Value)
        $updatedOrder = @($currentOrder | Where-Object { $TableNames -notcontains $_ })
        $updatedOrderJson = ConvertTo-PbiJsonText -InputObject $updatedOrder -Compress
        $content = [regex]::Replace(
            $content,
            "annotation PBI_QueryOrder = (\[.*?\])",
            ("annotation PBI_QueryOrder = " + $updatedOrderJson),
            [System.Text.RegularExpressions.RegexOptions]::Singleline
        )
    }

    foreach ($tableName in $TableNames) {
        $identifier = Get-PbiTmdlIdentifier -Name $tableName
        $refPattern = "(?m)^\s*ref table {0}\s*\r?\n?" -f [regex]::Escape($identifier)
        $content = [regex]::Replace($content, $refPattern, "")
    }

    Write-PbiUtf8File -Path $modelPath -Content $content
}

function Remove-PbiModulePageFromProject {
    param(
        [Parameter(Mandatory = $true)]$Project,
        [Parameter(Mandatory = $true)][string]$PageName
    )

    if ([string]::IsNullOrWhiteSpace($PageName)) {
        return
    }

    $pageRoot = Get-PbiPageDestinationRoot -Project $Project -PageName $PageName
    if (Test-Path $pageRoot) {
        Remove-Item -Path $pageRoot -Recurse -Force
    }

    $pagesMetadataPath = Get-PbiPagesMetadataPath -Project $Project
    if (-not (Test-Path $pagesMetadataPath)) {
        return
    }

    $pagesMetadata = Read-PbiJsonFile -Path $pagesMetadataPath
    $updatedPageOrder = @($pagesMetadata.pageOrder | Where-Object { $_ -ne $PageName })
    $pagesMetadata.pageOrder = $updatedPageOrder

    if ($pagesMetadata.activePageName -eq $PageName) {
        $pagesMetadata.activePageName = if ($updatedPageOrder.Count -gt 0) { $updatedPageOrder[0] } else { $null }
    }

    Write-PbiJsonFile -Path $pagesMetadataPath -InputObject $pagesMetadata
}

function Reset-PbiModuleInstallationInProject {
    param(
        [Parameter(Mandatory = $true)]$Project,
        [Parameter(Mandatory = $true)][string]$ModuleId,
        $StateRecord,
        $Module
    )

    $tableNames = @()
    if ($StateRecord) {
        $tableNames = @($StateRecord.installedObjects.tables)
    }
    elseif ($Module) {
        $tableNames = @($Module.Manifest.provides.semanticTables)
    }

    foreach ($tableName in $tableNames) {
        $tablePath = Get-PbiTableDefinitionPath -Project $Project -TableName $tableName
        if (Test-Path $tablePath) {
            Remove-Item -Path $tablePath -Force
        }
    }

    Remove-PbiTablesFromModel -Project $Project -TableNames $tableNames

    $pageName = ""
    if ($StateRecord) {
        $pageName = $StateRecord.installedObjects.page
    }
    elseif ($Module -and $Module.Manifest.provides.reportPage) {
        $pageName = $Module.Manifest.provides.reportPage.name
    }

    Remove-PbiModulePageFromProject -Project $Project -PageName $pageName

    $state = Get-PbiInstalledModulesState -Project $Project
    $state = Remove-PbiInstalledModuleRecord -State $state -ModuleId $ModuleId
    Save-PbiInstalledModulesState -Project $Project -State $state
}

function Get-PbiModuleDiffData {
    param(
        [Parameter(Mandatory = $true)]$Project,
        [Parameter(Mandatory = $true)]$Module,
        [Parameter(Mandatory = $true)]$StateRecord
    )

    $fileChanges = New-Object System.Collections.Generic.List[object]
    $sourceOwnedMappings = @(
        @(Get-PbiModuleSemanticFileMappings -Project $Project -Module $Module -Manifest $Module.Manifest) +
        @(Get-PbiModuleReportFileMappings -Project $Project -Module $Module -Manifest $Module.Manifest)
    )

    $sourceOwnedRelativePaths = @($sourceOwnedMappings | Select-Object -ExpandProperty RelativePath | Sort-Object -Unique)
    foreach ($mapping in $sourceOwnedMappings) {
        $installedExists = Test-Path $mapping.DestinationPath -PathType Leaf
        $sourceHash = if (Test-Path $mapping.SourcePath -PathType Leaf) { (Get-FileHash -Path $mapping.SourcePath -Algorithm SHA256).Hash } else { $null }
        $installedHash = if ($installedExists) { (Get-FileHash -Path $mapping.DestinationPath -Algorithm SHA256).Hash } else { $null }
        $status = if (-not $installedExists) {
            "missing-installed"
        }
        elseif ($sourceHash -eq $installedHash) {
            "unchanged"
        }
        else {
            "changed"
        }

        $fileChanges.Add([ordered]@{
            relativePath    = $mapping.RelativePath
            status          = $status
            sourcePath      = $mapping.SourcePath
            destinationPath = $mapping.DestinationPath
        })
    }

    $sharedPaths = New-Object System.Collections.Generic.List[string]
    $sharedPaths.Add((Get-PbiRelativePath -BasePath $Project.ProjectRoot -Path $Project.StateFilePath))
    if ((@($StateRecord.installedObjects.tables).Count -gt 0) -or (@($Module.Manifest.provides.semanticTables).Count -gt 0)) {
        $sharedPaths.Add((Get-PbiRelativePath -BasePath $Project.ProjectRoot -Path (Get-PbiModelPath -Project $Project)))
    }
    if ((-not [string]::IsNullOrWhiteSpace($StateRecord.installedObjects.page)) -or $Module.Manifest.provides.reportPage) {
        $sharedPaths.Add((Get-PbiRelativePath -BasePath $Project.ProjectRoot -Path (Get-PbiPagesMetadataPath -Project $Project)))
    }

    $extraInstalledFiles = @(
        $StateRecord.filesTouched |
            Where-Object {
                ($sourceOwnedRelativePaths -notcontains $_) -and
                (@($sharedPaths) -notcontains $_)
            } |
            Sort-Object -Unique
    )

    $sourceSemanticSummary = Get-PbiModuleSemanticObjectSummary -Module $Module -Manifest $Module.Manifest
    $installedSemantic = $StateRecord.semanticObjectsAdded

    return [ordered]@{
        generatedAt = Get-PbiUtcTimestamp
        moduleId    = $Module.ModuleId
        projectId   = $Project.ProjectId
        installedVersion = $StateRecord.version
        sourceVersion    = $Module.Version
        fileChanges = $fileChanges.ToArray()
        extraInstalledFiles = @($extraInstalledFiles)
        semanticObjects = [ordered]@{
            sourceTables      = @($sourceSemanticSummary.tables)
            installedTables   = @($installedSemantic.tables)
            addedTables       = @($sourceSemanticSummary.tables | Where-Object { @($installedSemantic.tables) -notcontains $_ })
            removedTables     = @($installedSemantic.tables | Where-Object { @($sourceSemanticSummary.tables) -notcontains $_ })
            sourceMeasures    = @($sourceSemanticSummary.measures)
            installedMeasures = @($installedSemantic.measures)
            addedMeasures     = @($sourceSemanticSummary.measures | Where-Object { @($installedSemantic.measures) -notcontains $_ })
            removedMeasures   = @($installedSemantic.measures | Where-Object { @($sourceSemanticSummary.measures) -notcontains $_ })
        }
        sharedProjectFilesImpacted = @($sharedPaths | Sort-Object -Unique)
    }
}

function Get-PbiModuleDiffMarkdown {
    param([Parameter(Mandatory = $true)]$Diff)

    $changedFiles = @($Diff.fileChanges | Where-Object { $_.status -ne "unchanged" })
    $lines = @(
        "# Module Diff",
        "",
        ('- Module: `{0}`' -f $Diff.moduleId),
        ('- Project: `{0}`' -f $Diff.projectId),
        ('- Installed version: `{0}`' -f $Diff.installedVersion),
        ('- Source version: `{0}`' -f $Diff.sourceVersion),
        ('- Generated at: `{0}`' -f $Diff.generatedAt),
        "",
        "## File Changes"
    )

    if ($changedFiles.Count -eq 0) {
        $lines += "- No owned file changes detected."
    }
    else {
        foreach ($fileChange in $changedFiles) {
            $lines += ('- `{0}`: {1}' -f $fileChange.relativePath, $fileChange.status)
        }
    }

    $lines += ""
    $lines += "## Extra Installed Files"
    if (@($Diff.extraInstalledFiles).Count -eq 0) {
        $lines += "- None."
    }
    else {
        foreach ($extraFile in @($Diff.extraInstalledFiles)) {
            $lines += ('- `{0}`' -f $extraFile)
        }
    }

    $lines += ""
    $lines += "## Semantic Object Delta"
    $lines += ("- Tables added: {0}" -f ((@($Diff.semanticObjects.addedTables) -join ", ")))
    $lines += ("- Tables removed: {0}" -f ((@($Diff.semanticObjects.removedTables) -join ", ")))
    $lines += ("- Measures added: {0}" -f ((@($Diff.semanticObjects.addedMeasures) -join ", ")))
    $lines += ("- Measures removed: {0}" -f ((@($Diff.semanticObjects.removedMeasures) -join ", ")))
    return ($lines -join "`r`n")
}

function Write-PbiModuleDiffArtifacts {
    param(
        [Parameter(Mandatory = $true)]$Project,
        [Parameter(Mandatory = $true)][string]$ModuleId,
        [Parameter(Mandatory = $true)]$Diff
    )

    $artifactRoot = Join-Path (Join-Path $Project.DiffRoot $ModuleId) (Get-PbiTimestampKey)
    Ensure-PbiDirectory -Path $artifactRoot

    $jsonPath = Join-Path $artifactRoot "diff.json"
    $markdownPath = Join-Path $artifactRoot "diff.md"

    Write-PbiJsonFile -Path $jsonPath -InputObject $Diff
    Write-PbiUtf8File -Path $markdownPath -Content (Get-PbiModuleDiffMarkdown -Diff $Diff)

    return [PSCustomObject]@{
        rootPath             = $artifactRoot
        jsonPath             = $jsonPath
        markdownPath         = $markdownPath
        jsonRelativePath     = (Get-PbiRelativePath -BasePath $Project.ProjectRoot -Path $jsonPath)
        markdownRelativePath = (Get-PbiRelativePath -BasePath $Project.ProjectRoot -Path $markdownPath)
    }
}

function Get-PbiSizeDeltaFromSnapshot {
    param(
        [Parameter(Mandatory = $true)]$Project,
        [Parameter(Mandatory = $true)]$Snapshot,
        [Parameter(Mandatory = $true)][string[]]$CurrentRelativePaths
    )

    $baselineByPath = @{}
    foreach ($entry in @($Snapshot.metadata.files)) {
        $baselineByPath[$entry.relativePath] = [int64]$entry.sizeBytes
    }

    $unionPaths = @($CurrentRelativePaths + @($baselineByPath.Keys) | Sort-Object -Unique)
    $delta = 0L

    foreach ($relativePath in $unionPaths) {
        $beforeSize = if ($baselineByPath.ContainsKey($relativePath)) { [int64]$baselineByPath[$relativePath] } else { 0L }
        $absolutePath = Join-Path $Project.ProjectRoot $relativePath
        $afterSize = if (Test-Path $absolutePath -PathType Leaf) { [int64](Get-PbiPathSizeBytes -Path $absolutePath) } else { 0L }
        $delta += ($afterSize - $beforeSize)
    }

    return $delta
}

function Merge-PbiGovernanceResults {
    param(
        [Parameter(Mandatory = $true)]$ImpactGovernance,
        $BaselineRepoHealthResult,
        $RepoHealthResult
    )

    $status = $ImpactGovernance.status
    $reasons = New-Object System.Collections.Generic.List[string]
    foreach ($reason in @($ImpactGovernance.reasons)) {
        $reasons.Add($reason)
    }

    if ($RepoHealthResult -and $RepoHealthResult.enabled) {
        $baselineStatus = if ($BaselineRepoHealthResult) { [string]$BaselineRepoHealthResult.status } else { "SKIPPED" }
        $postStatus = [string]$RepoHealthResult.status
        $baselineRank = Get-PbiGovernanceStatusRank -Status $baselineStatus
        $postRank = Get-PbiGovernanceStatusRank -Status $postStatus
        $baselineFailReasons = if ($BaselineRepoHealthResult) { @($BaselineRepoHealthResult.failReasons) } else { @() }
        $baselineWarningReasons = if ($BaselineRepoHealthResult) { @($BaselineRepoHealthResult.warningReasons) } else { @() }
        $newFailReasons = @($RepoHealthResult.failReasons | Where-Object { $baselineFailReasons -notcontains $_ })
        $newWarningReasons = @($RepoHealthResult.warningReasons | Where-Object { $baselineWarningReasons -notcontains $_ })

        if ($postStatus -eq "ERROR") {
            if ($status -eq "PASS") {
                $status = "WARN"
            }

            $reasons.Add(("repo-health hook failed: {0}" -f $RepoHealthResult.errorMessage))
        }
        elseif ($postRank -gt $baselineRank) {
            if ($postStatus -eq "FAIL") {
                $status = "FAIL"
            }
            elseif (($postStatus -eq "WARN") -and ($status -eq "PASS")) {
                $status = "WARN"
            }

            $reasons.Add(("repo-health status regressed from {0} to {1} after the module operation." -f $baselineStatus, $postStatus))
        }
        elseif (($postStatus -eq "FAIL") -and ($newFailReasons.Count -gt 0)) {
            $status = "FAIL"
            $reasons.Add("repo-health reported new blocking findings after the module operation.")
        }
        elseif (($postStatus -eq "WARN") -and ($newWarningReasons.Count -gt 0) -and ($status -eq "PASS")) {
            $status = "WARN"
            $reasons.Add("repo-health reported new warnings after the module operation.")
        }
    }

    return [ordered]@{
        status  = $status
        reasons = @($reasons)
    }
}

function Invoke-PbiManagedModuleWriteOperation {
    param(
        [Parameter(Mandatory = $true)][ValidateSet("install", "upgrade")][string]$Action,
        [string]$WorkspaceRoot,
        [Parameter(Mandatory = $true)][string]$ProjectPath,
        [string]$Domain,
        [Parameter(Mandatory = $true)][string]$ModuleId,
        [string]$MappingFile,
        [switch]$ActivateInstalledPage,
        [switch]$Force,
        [switch]$FailOnGovernanceBreach
    )

    $resolvedWorkspaceRoot = Get-PbiInstallerWorkspaceRoot -WorkspaceRoot $WorkspaceRoot -ScriptRoot $PSScriptRoot
    $project = Resolve-PbiConsumerProject -ProjectPath $ProjectPath
    $module = Get-PbiSingleModule -WorkspaceRoot $resolvedWorkspaceRoot -Domain $Domain -ModuleId $ModuleId
    $state = Get-PbiInstalledModulesState -Project $project
    $existingRecord = Get-PbiInstalledModuleRecord -State $state -ModuleId $ModuleId
    Ensure-PbiDirectory -Path $project.LogsRoot

    $logContext = New-PbiOperationContext -Command ("{0}-module" -f $Action) -ProjectId $project.ProjectId -ModuleId $ModuleId -LogRoot $project.LogsRoot
    Set-PbiOperationContext -Context $logContext

    try {
        $baselineRepoHealthOutputRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("pbi-repo-health-" + $project.ProjectId + "-" + $ModuleId + "-" + (Get-PbiTimestampKey))
        $baselineRepoHealthResult = Invoke-PbiRepoHealthHook -WorkspaceRoot $resolvedWorkspaceRoot -Project $project -OperationId ("baseline-" + (Get-PbiTimestampKey)) -OutputRoot $baselineRepoHealthOutputRoot

        $resolvedMappings = if ($existingRecord) {
            Merge-PbiModuleMappings -BaseMapping $existingRecord.mappings -OverrideMapping (Get-PbiMappingOverrides -MappingFile $MappingFile)
        }
        else {
            Resolve-PbiModuleMapping -Module $module -Project $project -OverrideMapping (Get-PbiMappingOverrides -MappingFile $MappingFile)
        }

        $forceReset = $false
        $diffArtifacts = $null

        if ($Action -eq "install") {
            if ($existingRecord) {
                if (($existingRecord.version -ne $module.Version) -and -not $Force) {
                    throw "Module '$ModuleId' is already installed at version '$($existingRecord.version)'. Use upgrade-module."
                }

                if (($existingRecord.version -eq $module.Version) -and -not $Force -and (Test-PbiModuleAlreadyInstalled -Project $project -Module $module)) {
                    Write-PbiInfo ("Module {0} is already aligned in project {1}. Returning no-op." -f $ModuleId, $project.ProjectId)
                    return [PSCustomObject]@{
                        Project     = $project
                        Module      = $module
                        StateRecord = $existingRecord
                        Action      = "no-op"
                        NoOp        = $true
                        LogPath     = $logContext.logFilePath
                    }
                }

                $forceReset = $true
            }
        }
        else {
            if (-not $existingRecord) {
                throw "Module '$ModuleId' is not currently installed in project '$($project.ProjectId)'."
            }

            $versionComparison = Compare-PbiVersion -LeftVersion $module.Version -RightVersion $existingRecord.version
            if (($versionComparison -lt 0) -and -not $Force) {
                throw "Catalog version '$($module.Version)' is older than installed version '$($existingRecord.version)'."
            }

            if (($versionComparison -eq 0) -and -not $Force) {
                Write-PbiInfo ("Module {0} is already on latest version {1}. Returning no-op." -f $ModuleId, $module.Version)
                return [PSCustomObject]@{
                    Project     = $project
                    Module      = $module
                    StateRecord = $existingRecord
                    Action      = "no-op"
                    NoOp        = $true
                    LogPath     = $logContext.logFilePath
                }
            }

            $diffData = Get-PbiModuleDiffData -Project $project -Module $module -StateRecord $existingRecord
            $diffArtifacts = Write-PbiModuleDiffArtifacts -Project $project -ModuleId $module.ModuleId -Diff $diffData
            $forceReset = $true
        }

        $snapshotPlan = Get-PbiModuleSnapshotPlan -Project $project -Module $module -StateRecord $existingRecord
        $snapshot = New-PbiModuleSnapshot -Project $project -ModuleId $ModuleId -Action $Action -SnapshotPlan $snapshotPlan -FromVersion $(if ($existingRecord) { $existingRecord.version } else { "" }) -ToVersion $module.Version
        Write-PbiInfo ("Created snapshot {0} for module {1}" -f $snapshot.snapshotId, $ModuleId)

        if ($forceReset) {
            Reset-PbiModuleInstallationInProject -Project $project -ModuleId $ModuleId -StateRecord $existingRecord -Module $module
        }

        $installResult = Install-PbiModulePackage `
            -WorkspaceRoot $resolvedWorkspaceRoot `
            -ProjectPath $project.PbipPath `
            -Domain $module.Domain `
            -ModuleId $module.ModuleId `
            -ResolvedMappings $resolvedMappings `
            -ActivateInstalledPage:$ActivateInstalledPage `
            -Force:$Force `
            -OperationMetadata ([ordered]@{
                action = $Action
                installedAt = Get-PbiUtcTimestamp
                history = [ordered]@{
                    lastSnapshotId       = $snapshot.snapshotId
                    lastDiffJsonPath     = if ($diffArtifacts) { $diffArtifacts.jsonRelativePath } else { "" }
                    lastDiffMarkdownPath = if ($diffArtifacts) { $diffArtifacts.markdownRelativePath } else { "" }
                    lastLogPath          = (Get-PbiRelativePath -BasePath $project.ProjectRoot -Path $logContext.logFilePath)
                }
                governance = [ordered]@{
                    status  = "PENDING"
                    reasons = @()
                }
                logPath = $logContext.logFilePath
            })

        if ($installResult.NoOp) {
            return $installResult
        }

        $impactMetrics = Get-PbiModuleImpactMetrics `
            -FilesTouched @($installResult.StateRecord.filesTouched) `
            -SemanticObjectsAdded $installResult.StateRecord.semanticObjectsAdded `
            -ReportObjectsAdded $installResult.StateRecord.reportObjectsAdded `
            -SizeDeltaBytes (Get-PbiSizeDeltaFromSnapshot -Project $project -Snapshot $snapshot -CurrentRelativePaths @($installResult.StateRecord.filesTouched))

        $impactGovernance = Test-PbiModuleImpactGovernance -ImpactMetrics $impactMetrics
        $repoHealthResult = Invoke-PbiRepoHealthHook -WorkspaceRoot $resolvedWorkspaceRoot -Project $project -OperationId $snapshot.snapshotId
        $combinedGovernance = Merge-PbiGovernanceResults -ImpactGovernance $impactGovernance -BaselineRepoHealthResult $baselineRepoHealthResult -RepoHealthResult $repoHealthResult

        $state = Get-PbiInstalledModulesState -Project $project
        $record = Get-PbiInstalledModuleRecord -State $state -ModuleId $ModuleId
        $record.impactMetrics = $impactMetrics
        $record.governance = $combinedGovernance
        $record.history.lastRepoHealthMetricsPath = if ($repoHealthResult.metricsPath) { Get-PbiRelativePath -BasePath $project.ProjectRoot -Path $repoHealthResult.metricsPath } else { "" }
        $record.history.lastRepoHealthSummaryPath = if ($repoHealthResult.summaryPath) { Get-PbiRelativePath -BasePath $project.ProjectRoot -Path $repoHealthResult.summaryPath } else { "" }
        $state = Set-PbiInstalledModuleRecord -State $state -Record $record
        Save-PbiInstalledModulesState -Project $project -State $state

        Write-PbiSuccess ("Module {0} {1} completed for project {2}" -f $ModuleId, $Action, $project.ProjectId)

        if ($FailOnGovernanceBreach -and ($combinedGovernance.status -eq "FAIL")) {
            throw "Governance thresholds failed after $Action for module '$ModuleId'."
        }

        return [PSCustomObject]@{
            Project               = $project
            Module                = $module
            StateRecord           = $record
            SnapshotId            = $snapshot.snapshotId
            DiffJsonPath          = if ($diffArtifacts) { $diffArtifacts.jsonPath } else { $null }
            DiffMarkdownPath      = if ($diffArtifacts) { $diffArtifacts.markdownPath } else { $null }
            RepoHealthMetricsPath = if ($repoHealthResult) { $repoHealthResult.metricsPath } else { $null }
            Governance            = $combinedGovernance
            Action                = $Action
            NoOp                  = $false
            LogPath               = $logContext.logFilePath
        }
    }
    catch {
        Write-PbiError -Message $_.Exception.Message
        throw
    }
    finally {
        Clear-PbiOperationContext
    }
}

function Invoke-PbiModuleInstallOperation {
    param(
        [string]$WorkspaceRoot,
        [Parameter(Mandatory = $true)][string]$ProjectPath,
        [string]$Domain,
        [Parameter(Mandatory = $true)][string]$ModuleId,
        [string]$MappingFile,
        [switch]$ActivateInstalledPage,
        [switch]$Force,
        [switch]$FailOnGovernanceBreach
    )

    return (Invoke-PbiManagedModuleWriteOperation -Action "install" -WorkspaceRoot $WorkspaceRoot -ProjectPath $ProjectPath -Domain $Domain -ModuleId $ModuleId -MappingFile $MappingFile -ActivateInstalledPage:$ActivateInstalledPage -Force:$Force -FailOnGovernanceBreach:$FailOnGovernanceBreach)
}

function Upgrade-PbiModulePackage {
    param(
        [string]$WorkspaceRoot,
        [Parameter(Mandatory = $true)][string]$ProjectPath,
        [string]$Domain,
        [Parameter(Mandatory = $true)][string]$ModuleId,
        [string]$MappingFile,
        [switch]$ActivateInstalledPage,
        [switch]$Force,
        [switch]$FailOnGovernanceBreach
    )

    return (Invoke-PbiManagedModuleWriteOperation -Action "upgrade" -WorkspaceRoot $WorkspaceRoot -ProjectPath $ProjectPath -Domain $Domain -ModuleId $ModuleId -MappingFile $MappingFile -ActivateInstalledPage:$ActivateInstalledPage -Force:$Force -FailOnGovernanceBreach:$FailOnGovernanceBreach)
}

function New-PbiModuleDiffReport {
    param(
        [string]$WorkspaceRoot,
        [Parameter(Mandatory = $true)][string]$ProjectPath,
        [string]$Domain,
        [Parameter(Mandatory = $true)][string]$ModuleId
    )

    $resolvedWorkspaceRoot = Get-PbiInstallerWorkspaceRoot -WorkspaceRoot $WorkspaceRoot -ScriptRoot $PSScriptRoot
    $project = Resolve-PbiConsumerProject -ProjectPath $ProjectPath
    $module = Get-PbiSingleModule -WorkspaceRoot $resolvedWorkspaceRoot -Domain $Domain -ModuleId $ModuleId
    $state = Get-PbiInstalledModulesState -Project $project
    $record = Get-PbiInstalledModuleRecord -State $state -ModuleId $ModuleId

    if (-not $record) {
        throw "Module '$ModuleId' is not currently installed in project '$($project.ProjectId)'."
    }

    $diffData = Get-PbiModuleDiffData -Project $project -Module $module -StateRecord $record
    $artifacts = Write-PbiModuleDiffArtifacts -Project $project -ModuleId $ModuleId -Diff $diffData

    return [PSCustomObject]@{
        Project          = $project
        Module           = $module
        DiffJsonPath     = $artifacts.jsonPath
        DiffMarkdownPath = $artifacts.markdownPath
    }
}

function Rollback-PbiModulePackage {
    param(
        [Parameter(Mandatory = $true)][string]$ProjectPath,
        [Parameter(Mandatory = $true)][string]$ModuleId,
        [string]$SnapshotId
    )

    $project = Resolve-PbiConsumerProject -ProjectPath $ProjectPath
    Ensure-PbiDirectory -Path $project.LogsRoot
    $logContext = New-PbiOperationContext -Command "rollback-module" -ProjectId $project.ProjectId -ModuleId $ModuleId -LogRoot $project.LogsRoot
    Set-PbiOperationContext -Context $logContext

    try {
        $snapshot = if ($SnapshotId) {
            Get-PbiModuleSnapshot -Project $project -ModuleId $ModuleId -SnapshotId $SnapshotId
        }
        else {
            Get-PbiLatestModuleSnapshot -Project $project -ModuleId $ModuleId
        }

        if (-not $snapshot) {
            throw "No snapshot was found for module '$ModuleId' in project '$($project.ProjectId)'."
        }

        Restore-PbiModuleSnapshot -Project $project -Snapshot $snapshot
        Write-PbiSuccess ("Rollback restored snapshot {0} for module {1}" -f $snapshot.snapshotId, $ModuleId)

        return [PSCustomObject]@{
            Project    = $project
            ModuleId   = $ModuleId
            SnapshotId = $snapshot.snapshotId
            LogPath    = $logContext.logFilePath
        }
    }
    catch {
        Write-PbiError -Message $_.Exception.Message
        throw
    }
    finally {
        Clear-PbiOperationContext
    }
}

Export-ModuleMember -Function New-PbiModuleSnapshot, Get-PbiLatestModuleSnapshot, Restore-PbiModuleSnapshot, Reset-PbiModuleInstallationInProject, Invoke-PbiModuleInstallOperation, Upgrade-PbiModulePackage, New-PbiModuleDiffReport, Rollback-PbiModulePackage
