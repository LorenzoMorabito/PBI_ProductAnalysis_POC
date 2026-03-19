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

function Get-PbiUnresolvedReportBindingTokenIssues {
    param(
        [Parameter(Mandatory = $true)][string]$Content,
        [Parameter(Mandatory = $true)][string]$Scope,
        [Parameter(Mandatory = $true)][string]$Target,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $results = New-Object System.Collections.Generic.List[object]
    $tokenPattern = "\{\{?binding(?:Label|Value|Table|Column|QueryRef):.+?\}\}?"
    $matches = [regex]::Matches($Content, $tokenPattern)
    foreach ($token in @($matches | ForEach-Object { $_.Value } | Select-Object -Unique)) {
        $results.Add((New-PbiQualityResult -Scope $Scope -Target $Target -RuleId "report.binding-token.unresolved" -Severity "Error" -Message ("Report asset still contains unresolved binding token '{0}'." -f $token) -Path $Path))
    }

    return $results.ToArray()
}

function Get-PbiReportBindingPlaceholderIssues {
    param(
        [Parameter(Mandatory = $true)][string]$Content,
        [Parameter(Mandatory = $true)][string]$Scope,
        [Parameter(Mandatory = $true)][string]$Target,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $results = New-Object System.Collections.Generic.List[object]
    $placeholderPattern = "MOD_BIND_(?:DIMENSION|MEASURE)_\d+(?:\[Value\])?"
    $matches = [regex]::Matches($Content, $placeholderPattern)
    foreach ($placeholder in @($matches | ForEach-Object { $_.Value } | Select-Object -Unique)) {
        $results.Add((New-PbiQualityResult -Scope $Scope -Target $Target -RuleId "report.binding-placeholder.forbidden" -Severity "Error" -Message ("Report asset still contains unresolved binding placeholder '{0}'." -f $placeholder) -Path $Path))
    }

    return $results.ToArray()
}

function Get-PbiVisualProjectionReferenceIssues {
    param(
        [Parameter(Mandatory = $true)]$VisualDefinition,
        [Parameter(Mandatory = $true)][string]$Scope,
        [Parameter(Mandatory = $true)][string]$Target,
        [Parameter(Mandatory = $true)][string]$VisualPath
    )

    $results = New-Object System.Collections.Generic.List[object]
    if (-not $VisualDefinition.visual -or -not $VisualDefinition.visual.query -or -not $VisualDefinition.visual.query.queryState) {
        return $results.ToArray()
    }

    foreach ($roleProperty in $VisualDefinition.visual.query.queryState.PSObject.Properties) {
        foreach ($projection in @($roleProperty.Value.projections)) {
            if (-not $projection.field -or [string]::IsNullOrWhiteSpace([string]$projection.queryRef)) {
                continue
            }

            if ($projection.field.PSObject.Properties.Name -contains "Column") {
                $columnField = $projection.field.Column
                $entity = [string]$columnField.Expression.SourceRef.Entity
                $property = [string]$columnField.Property
                if (($projection.queryRef -match "^(?<Entity>[^.]+)\.(?<Property>.+)$") -and
                    (($Matches.Entity -ne $entity) -or ($Matches.Property -ne $property))) {
                    $results.Add((New-PbiQualityResult -Scope $Scope -Target $Target -RuleId "report.projection.reference-consistent" -Severity "Error" -Message ("Visual projection field reference '{0}.{1}' does not match queryRef '{2}'." -f $entity, $property, $projection.queryRef) -Path $VisualPath))
                }
            }
            elseif ($projection.field.PSObject.Properties.Name -contains "Measure") {
                $measureField = $projection.field.Measure
                $entity = [string]$measureField.Expression.SourceRef.Entity
                $property = [string]$measureField.Property
                if (($projection.queryRef -match "^(?<Entity>[^.]+)\.(?<Property>.+)$") -and
                    (($Matches.Entity -ne $entity) -or ($Matches.Property -ne $property))) {
                    $results.Add((New-PbiQualityResult -Scope $Scope -Target $Target -RuleId "report.projection.reference-consistent" -Severity "Error" -Message ("Visual projection measure reference '{0}.{1}' does not match queryRef '{2}'." -f $entity, $property, $projection.queryRef) -Path $VisualPath))
                }
            }
        }
    }

    return $results.ToArray()
}

function Test-PbiNestedVisualValueCollection {
    param($Value)

    if ($null -eq $Value) {
        return $false
    }

    $items = @($Value)
    if ($items.Count -eq 0) {
        return $true
    }

    foreach ($item in $items) {
        if ($item -isnot [System.Array]) {
            return $false
        }
    }

    return $true
}

function Get-PbiVisualFieldParameterSlicerShapeIssues {
    param(
        [Parameter(Mandatory = $true)]$VisualDefinition,
        [string[]]$FieldParameterTables = @(),
        [Parameter(Mandatory = $true)][string]$Scope,
        [Parameter(Mandatory = $true)][string]$Target,
        [Parameter(Mandatory = $true)][string]$VisualPath
    )

    $results = New-Object System.Collections.Generic.List[object]

    if (-not $VisualDefinition.visual -or $VisualDefinition.visual.visualType -ne "slicer") {
        return $results.ToArray()
    }

    if (-not $VisualDefinition.visual.query -or -not $VisualDefinition.visual.query.queryState) {
        return $results.ToArray()
    }

    $projectedParameterTables = New-Object System.Collections.Generic.List[string]
    foreach ($roleProperty in $VisualDefinition.visual.query.queryState.PSObject.Properties) {
        foreach ($projection in @($roleProperty.Value.projections)) {
            if (-not $projection.field -or -not ($projection.field.PSObject.Properties.Name -contains "Column")) {
                continue
            }

            $entity = [string]$projection.field.Column.Expression.SourceRef.Entity
            if ($entity -and ($FieldParameterTables -contains $entity) -and -not $projectedParameterTables.Contains($entity)) {
                $projectedParameterTables.Add($entity)
            }
        }
    }

    if ($projectedParameterTables.Count -eq 0) {
        return $results.ToArray()
    }

    foreach ($generalObject in @($VisualDefinition.visual.objects.general)) {
        $whereClauses = @($generalObject.properties.filter.filter.Where)
        foreach ($whereClause in $whereClauses) {
            $metadata = $whereClause.Annotations.filterExpressionMetadata
            if (-not $metadata -or -not $metadata.decomposedIdentities) {
                continue
            }

            $filterValues = $whereClause.Condition.In.Values
            if (-not (Test-PbiNestedVisualValueCollection -Value $filterValues)) {
                $results.Add((New-PbiQualityResult -Scope $Scope -Target $Target -RuleId "report.field-parameter.slicer-shape.valid" -Severity "Error" -Message "Field-parameter slicer filter Values must be an array of arrays." -Path $VisualPath))
            }

            $decomposedValues = $metadata.decomposedIdentities.values
            if (-not (Test-PbiNestedVisualValueCollection -Value $decomposedValues)) {
                $results.Add((New-PbiQualityResult -Scope $Scope -Target $Target -RuleId "report.field-parameter.slicer-shape.valid" -Severity "Error" -Message "Field-parameter slicer decomposedIdentities.values must be an array of arrays." -Path $VisualPath))
            }

            $filterValueCount = @($filterValues).Count
            $decomposedValueCount = @($decomposedValues).Count
            if (($filterValueCount -gt 0) -and ($decomposedValueCount -gt 0) -and ($filterValueCount -ne $decomposedValueCount)) {
                $results.Add((New-PbiQualityResult -Scope $Scope -Target $Target -RuleId "report.field-parameter.slicer-shape.valid" -Severity "Error" -Message ("Field-parameter slicer filter Values count ({0}) does not match decomposedIdentities.values count ({1})." -f $filterValueCount, $decomposedValueCount) -Path $VisualPath))
            }

            $valueMapCount = @($metadata.valueMap).Count
            if (($filterValueCount -gt 0) -and ($valueMapCount -gt 0) -and ($filterValueCount -ne $valueMapCount)) {
                $results.Add((New-PbiQualityResult -Scope $Scope -Target $Target -RuleId "report.field-parameter.slicer-shape.valid" -Severity "Error" -Message ("Field-parameter slicer filter Values count ({0}) does not match valueMap count ({1})." -f $filterValueCount, $valueMapCount) -Path $VisualPath))
            }
        }
    }

    return $results.ToArray()
}

function New-PbiReportRenderValidationProject {
    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("pbi-report-render-validation-" + [guid]::NewGuid().ToString("N"))
    $reportPath = Join-Path $tempRoot "RenderValidation.Report"
    Ensure-PbiDirectory -Path (Join-Path $reportPath "definition/pages")

    return [PSCustomObject]@{
        ProjectRoot = $tempRoot
        ReportPath  = $reportPath
    }
}

function Get-PbiRenderedModuleReportIssues {
    param([Parameter(Mandatory = $true)]$Module)

    $results = New-Object System.Collections.Generic.List[object]
    if (-not $Module.Manifest.provides.reportPage) {
        return $results.ToArray()
    }

    $parameterTables = @(Get-PbiFieldParameterTableNamesFromDirectory -TableDirectory (Join-Path $Module.PackageRoot "semantic"))

    $validationProject = $null
    try {
        $validationProject = New-PbiReportRenderValidationProject
        $validationMappings = ConvertTo-PbiResolvedMappings -Mappings (Get-PbiBindingContractDefaultMappings -Manifest $Module.Manifest)
        $renderedAssets = @(Get-PbiRenderedModuleReportAssets -Project $validationProject -Module $Module -Manifest $Module.Manifest -ResolvedMappings $validationMappings)

        foreach ($asset in $renderedAssets) {
            $renderedPath = if ($asset.RelativePath) { ("rendered::{0}" -f $asset.RelativePath) } else { ("rendered::{0}" -f [System.IO.Path]::GetFileName($asset.DestinationPath)) }
            $content = [string]$asset.SourceContent

            foreach ($issue in (Get-PbiUnresolvedReportBindingTokenIssues -Content $content -Scope "Module" -Target $Module.ModuleId -Path $renderedPath)) {
                $results.Add($issue)
            }
            foreach ($issue in (Get-PbiReportBindingPlaceholderIssues -Content $content -Scope "Module" -Target $Module.ModuleId -Path $renderedPath)) {
                $results.Add($issue)
            }

            if ($renderedPath -like "*.json" -or $renderedPath -match "\.json$") {
                try {
                    $renderedDefinition = ConvertFrom-PbiJsonText -Text $content
                    foreach ($issue in (Get-PbiVisualProjectionReferenceIssues -VisualDefinition $renderedDefinition -Scope "Module" -Target $Module.ModuleId -VisualPath $renderedPath)) {
                        $results.Add($issue)
                    }
                    foreach ($issue in (Get-PbiVisualFieldParameterSlicerShapeIssues -VisualDefinition $renderedDefinition -FieldParameterTables $parameterTables -Scope "Module" -Target $Module.ModuleId -VisualPath $renderedPath)) {
                        $results.Add($issue)
                    }
                }
                catch {
                    $results.Add((New-PbiQualityResult -Scope "Module" -Target $Module.ModuleId -RuleId "report.render.succeeds" -Severity "Error" -Message ("Rendered report asset could not be parsed as JSON: {0}" -f $_.Exception.Message) -Path $renderedPath))
                }
            }
        }
    }
    catch {
        $results.Add((New-PbiQualityResult -Scope "Module" -Target $Module.ModuleId -RuleId "report.render.succeeds" -Severity "Error" -Message ("Dynamic report assets could not be rendered for validation: {0}" -f $_.Exception.Message) -Path $Module.PackageRoot))
    }
    finally {
        if ($validationProject -and (Test-Path $validationProject.ProjectRoot)) {
            Remove-Item -Path $validationProject.ProjectRoot -Recurse -Force
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
    $parameterTables = @(Get-PbiFieldParameterTableNamesFromDirectory -TableDirectory (Join-Path $Module.PackageRoot "semantic"))
    $allowedModuleTables = @($Module.Manifest.provides.semanticTables)
    $allowedCoreTables = Get-PbiManifestReferencedCoreTableNames -Manifest $Module.Manifest
    $allowedEntities = @($allowedModuleTables + $allowedCoreTables | Select-Object -Unique)

    foreach ($jsonFile in $reportJsonFiles) {
        $rawJson = Get-Content -Path $jsonFile.FullName -Raw
        try {
            $null = ConvertFrom-PbiJsonText -Text $rawJson
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
            $visualDefinition = ConvertFrom-PbiJsonText -Text $raw
            foreach ($issue in (Get-PbiVisualParameterProjectionIssues -VisualDefinition $visualDefinition -FieldParameterTables $parameterTables -VisualPath $visualFile.FullName)) {
                $results.Add($issue)
            }
            foreach ($issue in (Get-PbiVisualFieldParameterSlicerShapeIssues -VisualDefinition $visualDefinition -FieldParameterTables $parameterTables -Scope "Module" -Target $Module.ModuleId -VisualPath $visualFile.FullName)) {
                $results.Add($issue)
            }
            foreach ($issue in (Get-PbiVisualProjectionReferenceIssues -VisualDefinition $visualDefinition -Scope "Module" -Target $Module.ModuleId -VisualPath $visualFile.FullName)) {
                $results.Add($issue)
            }
        }
        catch {
            # JSON parse is already emitted above.
        }
    }

    foreach ($issue in (Get-PbiRenderedModuleReportIssues -Module $Module)) {
        $results.Add($issue)
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
    $parameterTables = @(Get-PbiFieldParameterTableNamesFromDirectory -TableDirectory $tableDirectory)

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
        $rawJson = Get-Content -Path $jsonFile.FullName -Raw
        foreach ($issue in (Get-PbiUnresolvedReportBindingTokenIssues -Content $rawJson -Scope "Project" -Target $Project.ProjectId -Path $jsonFile.FullName)) {
            $results.Add($issue)
        }
        foreach ($issue in (Get-PbiReportBindingPlaceholderIssues -Content $rawJson -Scope "Project" -Target $Project.ProjectId -Path $jsonFile.FullName)) {
            $results.Add($issue)
        }

        try {
            $null = ConvertFrom-PbiJsonText -Text $rawJson
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
            $visualDefinition = ConvertFrom-PbiJsonText -Text $raw
            foreach ($issue in (Get-PbiVisualParameterProjectionIssues -VisualDefinition $visualDefinition -FieldParameterTables $parameterTables -VisualPath $visualFile.FullName)) {
                $results.Add($issue)
            }
            foreach ($issue in (Get-PbiVisualFieldParameterSlicerShapeIssues -VisualDefinition $visualDefinition -FieldParameterTables $parameterTables -Scope "Project" -Target $Project.ProjectId -VisualPath $visualFile.FullName)) {
                $results.Add($issue)
            }
            foreach ($issue in (Get-PbiVisualProjectionReferenceIssues -VisualDefinition $visualDefinition -Scope "Project" -Target $Project.ProjectId -VisualPath $visualFile.FullName)) {
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
