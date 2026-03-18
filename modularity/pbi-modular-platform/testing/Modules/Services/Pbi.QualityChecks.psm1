function Get-PbiQualityRuleCatalog {
    return @(
        [PSCustomObject]@{ Scope = "Module"; RuleId = "module.manifest.valid"; Description = "Required manifest properties are present."; Severity = "Error" },
        [PSCustomObject]@{ Scope = "Module"; RuleId = "module.manifest.schema"; Description = "Manifest conforms to the governed schema and cross-field contract."; Severity = "Error" },
        [PSCustomObject]@{ Scope = "Module"; RuleId = "module.semantic-table.exists"; Description = "Every declared semantic table file exists."; Severity = "Error" },
        [PSCustomObject]@{ Scope = "Module"; RuleId = "module.report-page.exists"; Description = "Declared report page assets exist."; Severity = "Error" },
        [PSCustomObject]@{ Scope = "Module"; RuleId = "architecture.module.core-table.forbidden"; Description = "Modules do not declare semantic tables reserved for the semantic core contract."; Severity = "Error" },
        [PSCustomObject]@{ Scope = "Module"; RuleId = "architecture.module.semantic-namespace.required"; Description = "Semantic modules must keep tables in the MOD namespace and match their classification contract."; Severity = "Error" },
        [PSCustomObject]@{ Scope = "Module"; RuleId = "semantic.measure-name.unique"; Description = "Measure names are unique within the module."; Severity = "Error" },
        [PSCustomObject]@{ Scope = "Module"; RuleId = "semantic.local-path.forbidden"; Description = "Semantic assets do not contain hardcoded local absolute paths."; Severity = "Error" },
        [PSCustomObject]@{ Scope = "Module"; RuleId = "report.json.parse"; Description = "All report asset JSON files parse correctly."; Severity = "Error" },
        [PSCustomObject]@{ Scope = "Module"; RuleId = "report.entity.module-reference"; Description = "Module visuals do not reference undeclared MOD tables."; Severity = "Error" },
        [PSCustomObject]@{ Scope = "Module"; RuleId = "report.textbox.no-query"; Description = "Textbox visuals do not carry semantic queries."; Severity = "Error" },
        [PSCustomObject]@{ Scope = "Module"; RuleId = "report.field-parameter.requires-metadata"; Description = "Non-slicer visuals do not project field parameter tables directly without metadata."; Severity = "Error" },
        [PSCustomObject]@{ Scope = "Project"; RuleId = "architecture.core-contract.table-allowed"; Description = "The core baseline project only contains tables approved by the semantic core contract."; Severity = "Error" },
        [PSCustomObject]@{ Scope = "Project"; RuleId = "architecture.core-contract.table-required"; Description = "The core baseline project contains every required core table."; Severity = "Error" },
        [PSCustomObject]@{ Scope = "Project"; RuleId = "architecture.core-contract.no-installed-modules"; Description = "The core baseline project does not carry installed module metadata."; Severity = "Error" },
        [PSCustomObject]@{ Scope = "Project"; RuleId = "architecture.relationship.crossfilter.required"; Description = "Declared relationship requirements from the architecture contract are respected."; Severity = "Error" },
        [PSCustomObject]@{ Scope = "Project"; RuleId = "project.installed-state.valid"; Description = "Installed module state is schema-valid and internally consistent."; Severity = "Error" },
        [PSCustomObject]@{ Scope = "Project"; RuleId = "semantic.measure-name.unique"; Description = "Measure names are unique across the whole semantic model."; Severity = "Error" },
        [PSCustomObject]@{ Scope = "Project"; RuleId = "semantic.local-path.forbidden"; Description = "Semantic model definitions do not contain hardcoded local absolute paths."; Severity = "Error" },
        [PSCustomObject]@{ Scope = "Project"; RuleId = "semantic.root-path.placeholder.unresolved"; Description = "The project root_path parameter is still unresolved and must be configured locally before Desktop usage."; Severity = "Warning" },
        [PSCustomObject]@{ Scope = "Project"; RuleId = "semantic.root-path.absolute.required"; Description = "The project root_path parameter resolves to an absolute path."; Severity = "Error" },
        [PSCustomObject]@{ Scope = "Project"; RuleId = "report.page-folder.exists"; Description = "Every page in pages.json has a folder and page.json."; Severity = "Error" },
        [PSCustomObject]@{ Scope = "Project"; RuleId = "report.active-page.valid"; Description = "The active page is present in pageOrder."; Severity = "Error" },
        [PSCustomObject]@{ Scope = "Project"; RuleId = "report.entity.project-reference"; Description = "Visual entities resolve to tables present in the semantic model."; Severity = "Error" }
    )
}

function Copy-PbiPathPreservingLayout {
    param(
        [Parameter(Mandatory = $true)][string]$SourceRoot,
        [Parameter(Mandatory = $true)][string]$SourcePath,
        [Parameter(Mandatory = $true)][string]$DestinationRoot
    )

    $relativePath = (Get-PbiRelativePath -BasePath $SourceRoot -Path $SourcePath).Replace("/", "\")
    $destinationPath = Join-Path $DestinationRoot $relativePath
    $destinationParent = Split-Path $destinationPath -Parent
    Ensure-PbiDirectory -Path $destinationParent

    if ((Get-Item $SourcePath).PSIsContainer) {
        Copy-Item -Path $SourcePath -Destination $destinationPath -Recurse -Force
    }
    else {
        Copy-Item -Path $SourcePath -Destination $destinationPath -Force
    }

    return $destinationPath
}

function New-PbiSmokeProjectCopy {
    param(
        [Parameter(Mandatory = $true)]$Project,
        [string]$TempRoot
    )

    if (-not $TempRoot) {
        $TempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("pbi-quality-" + [guid]::NewGuid().ToString("N"))
    }

    Ensure-PbiDirectory -Path $TempRoot
    $copiedPbipPath = Copy-PbiPathPreservingLayout -SourceRoot $Project.ProjectRoot -SourcePath $Project.PbipPath -DestinationRoot $TempRoot
    $null = Copy-PbiPathPreservingLayout -SourceRoot $Project.ProjectRoot -SourcePath $Project.ReportPath -DestinationRoot $TempRoot
    $null = Copy-PbiPathPreservingLayout -SourceRoot $Project.ProjectRoot -SourcePath $Project.SemanticModelPath -DestinationRoot $TempRoot

    if (Test-Path $Project.ModuleConfigDir) {
        $null = Copy-PbiPathPreservingLayout -SourceRoot $Project.ProjectRoot -SourcePath $Project.ModuleConfigDir -DestinationRoot $TempRoot
    }

    return (Resolve-PbiConsumerProject -ProjectPath $copiedPbipPath)
}

function Invoke-PbiModuleQualityChecks {
    param(
        [string]$WorkspaceRoot,
        [string]$Domain,
        [string]$ModuleId
    )

    $modules = Get-PbiModuleList -WorkspaceRoot $WorkspaceRoot -Domain $Domain -ModuleId $ModuleId
    $results = New-Object System.Collections.Generic.List[object]

    foreach ($module in $modules) {
        foreach ($result in (Invoke-PbiModuleManifestRules -Module $module)) {
            $results.Add($result)
        }

        foreach ($result in (Invoke-PbiModuleArchitectureRules -Module $module)) {
            $results.Add($result)
        }

        foreach ($result in (Invoke-PbiModuleSemanticRules -Module $module)) {
            $results.Add($result)
        }

        foreach ($result in (Invoke-PbiModuleReportRules -Module $module)) {
            $results.Add($result)
        }
    }

    return [PSCustomObject]@{
        Results = $results.ToArray()
        Counts  = (Get-PbiQualityResultCounts -Results $results.ToArray())
    }
}

function Invoke-PbiProjectQualityChecks {
    param(
        [Parameter(Mandatory = $true)][string]$ProjectPath
    )

    $project = Resolve-PbiConsumerProject -ProjectPath $ProjectPath
    $results = New-Object System.Collections.Generic.List[object]

    foreach ($result in (Invoke-PbiProjectArchitectureRules -Project $project)) {
        $results.Add($result)
    }

    foreach ($result in (Invoke-PbiProjectSemanticRules -Project $project)) {
        $results.Add($result)
    }

    foreach ($result in (Invoke-PbiProjectReportRules -Project $project)) {
        $results.Add($result)
    }

    return [PSCustomObject]@{
        Project = $project
        Results = $results.ToArray()
        Counts  = (Get-PbiQualityResultCounts -Results $results.ToArray())
    }
}

function Invoke-PbiRepoQualityChecks {
    param(
        [string]$WorkspaceRoot,
        [string]$Domain,
        [string]$ModuleId
    )

    $resolvedWorkspaceRoot = Get-PbiInstallerWorkspaceRoot -WorkspaceRoot $WorkspaceRoot -ScriptRoot $PSScriptRoot
    $moduleCheck = Invoke-PbiModuleQualityChecks -WorkspaceRoot $resolvedWorkspaceRoot -Domain $Domain -ModuleId $ModuleId
    $results = New-Object System.Collections.Generic.List[object]

    foreach ($result in $moduleCheck.Results) {
        $results.Add($result)
    }

    foreach ($pbipFile in (Get-PbiPbipFilesFromWorkspace -WorkspaceRoot $resolvedWorkspaceRoot)) {
        $projectCheck = Invoke-PbiProjectQualityChecks -ProjectPath $pbipFile.FullName
        foreach ($result in @($projectCheck.Results)) {
            $results.Add($result)
        }
    }

    return [PSCustomObject]@{
        Results = $results.ToArray()
        Counts  = (Get-PbiQualityResultCounts -Results $results.ToArray())
    }
}

function Invoke-PbiSmokeInstallCheck {
    param(
        [string]$WorkspaceRoot,
        [Parameter(Mandatory = $true)][string]$ProjectPath,
        [string]$Domain,
        [Parameter(Mandatory = $true)][string]$ModuleId,
        [string]$TempRoot,
        [switch]$KeepTempCopy
    )

    $resolvedWorkspaceRoot = Get-PbiInstallerWorkspaceRoot -WorkspaceRoot $WorkspaceRoot -ScriptRoot $PSScriptRoot
    $sourceProject = Resolve-PbiConsumerProject -ProjectPath $ProjectPath
    $module = Get-PbiSingleModule -WorkspaceRoot $resolvedWorkspaceRoot -Domain $Domain -ModuleId $ModuleId
    $tempProject = New-PbiSmokeProjectCopy -Project $sourceProject -TempRoot $TempRoot

    try {
        $tempState = Get-PbiInstalledModulesState -Project $tempProject
        $tempRecord = Get-PbiInstalledModuleRecord -State $tempState -ModuleId $module.ModuleId
        Reset-PbiModuleInstallationInProject -Project $tempProject -ModuleId $module.ModuleId -StateRecord $tempRecord -Module $module
        $installResult = Install-PbiModulePackage -WorkspaceRoot $resolvedWorkspaceRoot -ProjectPath $tempProject.PbipPath -Domain $module.Domain -ModuleId $module.ModuleId -ActivateInstalledPage
        $projectCheck = Invoke-PbiProjectQualityChecks -ProjectPath $tempProject.PbipPath
        $results = New-Object System.Collections.Generic.List[object]

        $results.Add((New-PbiQualityResult -Scope "SmokeInstall" -Target $module.ModuleId -RuleId "smoke.install.completed" -Severity "Info" -Message ("Module installed into sandbox project '{0}'." -f $installResult.Project.ProjectId) -Path $tempProject.PbipPath))
        foreach ($result in $projectCheck.Results) {
            $results.Add($result)
        }

        return [PSCustomObject]@{
            TempProject = $tempProject
            Results     = $results.ToArray()
            Counts      = (Get-PbiQualityResultCounts -Results $results.ToArray())
        }
    }
    finally {
        if (-not $KeepTempCopy -and $tempProject -and (Test-Path $tempProject.ProjectRoot)) {
            Remove-Item -Path $tempProject.ProjectRoot -Recurse -Force
        }
    }
}

Export-ModuleMember -Function Get-PbiQualityRuleCatalog, Invoke-PbiModuleQualityChecks, Invoke-PbiProjectQualityChecks, Invoke-PbiRepoQualityChecks, Invoke-PbiSmokeInstallCheck
