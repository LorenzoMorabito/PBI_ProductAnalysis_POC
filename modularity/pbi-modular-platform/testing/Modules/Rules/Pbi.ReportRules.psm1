function Get-PbiVisualParameterProjectionIssues {
    param(
        [Parameter(Mandatory = $true)]$VisualDefinition,
        [Parameter(Mandatory = $true)][string[]]$FieldParameterTables,
        [Parameter(Mandatory = $true)][string]$VisualPath
    )

    $results = New-Object System.Collections.Generic.List[object]

    if (-not $VisualDefinition.visual) {
        return $results.ToArray()
    }

    if ($VisualDefinition.visual.visualType -eq "textbox" -and $VisualDefinition.visual.PSObject.Properties.Name.Contains("query")) {
        $results.Add((New-PbiQualityResult -Scope "Visual" -Target $VisualDefinition.name -RuleId "report.textbox.no-query" -Severity "Error" -Message "Textbox visual should not define a semantic query." -Path $VisualPath))
    }

    if (-not $VisualDefinition.visual.query -or -not $VisualDefinition.visual.query.queryState) {
        return $results.ToArray()
    }

    foreach ($roleProperty in $VisualDefinition.visual.query.queryState.PSObject.Properties) {
        $roleState = $roleProperty.Value
        $projections = @($roleState.projections)

        if ($projections.Count -eq 0) {
            continue
        }

        $directParameterProjections = @(
            $projections | Where-Object {
                $_.field.Column.Expression.SourceRef.Entity -and
                ($FieldParameterTables -contains $_.field.Column.Expression.SourceRef.Entity)
            }
        )

        if ($directParameterProjections.Count -gt 0 -and $VisualDefinition.visual.visualType -ne "slicer") {
            $hasFieldParameters = (@($roleState.fieldParameters).Count -gt 0)

            if (-not $hasFieldParameters) {
                $parameterTableList = @($directParameterProjections | ForEach-Object { $_.field.Column.Expression.SourceRef.Entity } | Select-Object -Unique)
                $results.Add((New-PbiQualityResult -Scope "Visual" -Target $VisualDefinition.name -RuleId "report.field-parameter.requires-metadata" -Severity "Error" -Message ("Visual projects field parameter table(s) directly without fieldParameters metadata: {0}" -f ($parameterTableList -join ", ")) -Path $VisualPath))
            }
        }
    }

    return $results.ToArray()
}

function Invoke-PbiModuleReportRules {
    param([Parameter(Mandatory = $true)]$Module)

    $results = New-Object System.Collections.Generic.List[object]
    $reportRoot = Join-Path $Module.PackageRoot "report"
    $reportJsonFiles = Get-PbiReportJsonFilesFromRoot -ReportRoot $reportRoot
    $visualFiles = Get-PbiVisualJsonFilesFromRoot -ReportRoot $reportRoot
    $parameterTables = Get-PbiFieldParameterTableNamesFromDirectory -TableDirectory (Join-Path $Module.PackageRoot "semantic")
    $allowedModuleTables = @($Module.Manifest.provides.semanticTables)
    $allowedCoreTables = Get-PbiManifestReferencedCoreTableNames -Manifest $Module.Manifest
    $allowedEntities = @($allowedModuleTables + $allowedCoreTables | Select-Object -Unique)

    foreach ($jsonFile in $reportJsonFiles) {
        try {
            $null = Get-Content -Path $jsonFile.FullName -Raw | ConvertFrom-Json -Depth 100
        }
        catch {
            $results.Add((New-PbiQualityResult -Scope "Module" -Target $Module.ModuleId -RuleId "report.json.parse" -Severity "Error" -Message $_.Exception.Message -Path $jsonFile.FullName))
        }
    }

    foreach ($visualFile in $visualFiles) {
        $raw = Get-Content -Path $visualFile.FullName -Raw
        $entityReferences = Get-PbiEntityNamesFromJsonText -Content $raw

        foreach ($entityName in @($entityReferences | Where-Object { $_ -like "MOD *" -and $allowedEntities -notcontains $_ })) {
            $results.Add((New-PbiQualityResult -Scope "Module" -Target $Module.ModuleId -RuleId "report.entity.module-reference" -Severity "Error" -Message ("Visual references module table '{0}' that is not provided by the manifest." -f $entityName) -Path $visualFile.FullName))
        }

        try {
            $visualDefinition = $raw | ConvertFrom-Json -Depth 100
            foreach ($issue in (Get-PbiVisualParameterProjectionIssues -VisualDefinition $visualDefinition -FieldParameterTables $parameterTables -VisualPath $visualFile.FullName)) {
                $results.Add($issue)
            }
        }
        catch {
            # JSON parse is already emitted above.
        }
    }

    return $results.ToArray()
}

function Invoke-PbiProjectReportRules {
    param([Parameter(Mandatory = $true)]$Project)

    $results = New-Object System.Collections.Generic.List[object]
    $reportDefinitionRoot = Join-Path $Project.ReportPath "definition"
    $reportJsonFiles = Get-PbiReportJsonFilesFromRoot -ReportRoot $reportDefinitionRoot
    $visualFiles = Get-PbiVisualJsonFilesFromRoot -ReportRoot $reportDefinitionRoot
    $tableDirectory = Get-PbiTableDefinitionDirectoryForProject -Project $Project
    $projectTables = Get-PbiTmdlTableNamesFromDirectory -TableDirectory $tableDirectory
    $parameterTables = Get-PbiFieldParameterTableNamesFromDirectory -TableDirectory $tableDirectory

    $pagesMetadataPath = Get-PbiPagesMetadataPathForProject -Project $Project
    try {
        $pagesMetadata = Read-PbiJsonFile -Path $pagesMetadataPath
        foreach ($pageName in @($pagesMetadata.pageOrder)) {
            $pageRoot = Get-PbiPageDestinationRootForProject -Project $Project -PageName $pageName
            $pageJsonPath = Join-Path $pageRoot "page.json"

            if (-not (Test-Path $pageRoot)) {
                $results.Add((New-PbiQualityResult -Scope "Project" -Target $Project.ProjectId -RuleId "report.page-folder.exists" -Severity "Error" -Message ("Page folder '{0}' is missing." -f $pageName) -Path $pageRoot))
            }
            elseif (-not (Test-Path $pageJsonPath)) {
                $results.Add((New-PbiQualityResult -Scope "Project" -Target $Project.ProjectId -RuleId "report.page-json.exists" -Severity "Error" -Message ("page.json is missing for page '{0}'." -f $pageName) -Path $pageJsonPath))
            }
        }

        if ($pagesMetadata.activePageName -and $pagesMetadata.pageOrder -notcontains $pagesMetadata.activePageName) {
            $results.Add((New-PbiQualityResult -Scope "Project" -Target $Project.ProjectId -RuleId "report.active-page.valid" -Severity "Error" -Message ("Active page '{0}' is not present in pageOrder." -f $pagesMetadata.activePageName) -Path $pagesMetadataPath))
        }
    }
    catch {
        $results.Add((New-PbiQualityResult -Scope "Project" -Target $Project.ProjectId -RuleId "report.pages-metadata.parse" -Severity "Error" -Message $_.Exception.Message -Path $pagesMetadataPath))
    }

    foreach ($jsonFile in $reportJsonFiles) {
        try {
            $null = Get-Content -Path $jsonFile.FullName -Raw | ConvertFrom-Json -Depth 100
        }
        catch {
            $results.Add((New-PbiQualityResult -Scope "Project" -Target $Project.ProjectId -RuleId "report.json.parse" -Severity "Error" -Message $_.Exception.Message -Path $jsonFile.FullName))
        }
    }

    foreach ($visualFile in $visualFiles) {
        $raw = Get-Content -Path $visualFile.FullName -Raw
        $entityReferences = Get-PbiEntityNamesFromJsonText -Content $raw

        foreach ($entityName in @($entityReferences | Where-Object { $projectTables -notcontains $_ })) {
            $results.Add((New-PbiQualityResult -Scope "Project" -Target $Project.ProjectId -RuleId "report.entity.project-reference" -Severity "Error" -Message ("Visual references entity '{0}' that does not exist in the semantic model." -f $entityName) -Path $visualFile.FullName))
        }

        try {
            $visualDefinition = $raw | ConvertFrom-Json -Depth 100
            foreach ($issue in (Get-PbiVisualParameterProjectionIssues -VisualDefinition $visualDefinition -FieldParameterTables $parameterTables -VisualPath $visualFile.FullName)) {
                $results.Add($issue)
            }
        }
        catch {
            # JSON parse is already emitted above.
        }
    }

    return $results.ToArray()
}

Export-ModuleMember -Function Invoke-PbiModuleReportRules, Invoke-PbiProjectReportRules
