function Invoke-PbiModuleArchitectureRules {
    param([Parameter(Mandatory = $true)]$Module)

    $results = New-Object System.Collections.Generic.List[object]
    $contract = Get-PbiArchitectureContract
    $coreTableSet = @($contract.coreAllowedTables)
    $semanticTables = @($Module.Manifest.provides.semanticTables)

    foreach ($tableName in $semanticTables) {
        if ($coreTableSet -contains $tableName) {
            $results.Add((New-PbiQualityResult -Scope "Module" -Target $Module.ModuleId -RuleId "architecture.module.core-table.forbidden" -Severity "Error" -Message ("Module declares semantic table '{0}', but that table belongs to the semantic core contract." -f $tableName) -Path (Join-Path $Module.PackageRoot "manifest.json")))
        }

        if ($tableName -notlike "MOD *") {
            $results.Add((New-PbiQualityResult -Scope "Module" -Target $Module.ModuleId -RuleId "architecture.module.semantic-namespace.required" -Severity "Error" -Message ("Semantic table '{0}' must stay in the MOD namespace." -f $tableName) -Path (Join-Path $Module.PackageRoot "manifest.json")))
        }
    }

    if (($Module.Manifest.classification -eq "report-only") -and ($semanticTables.Count -gt 0)) {
        $results.Add((New-PbiQualityResult -Scope "Module" -Target $Module.ModuleId -RuleId "architecture.module.semantic-namespace.required" -Severity "Error" -Message "report-only modules cannot declare semantic tables." -Path (Join-Path $Module.PackageRoot "manifest.json")))
    }

    return $results.ToArray()
}

function Get-PbiRelationshipDefinitionBlocks {
    param([Parameter(Mandatory = $true)][string]$RelationshipsPath)

    if (-not (Test-Path $RelationshipsPath)) {
        return @()
    }

    $content = Get-Content -Path $RelationshipsPath -Raw
    $matches = [regex]::Matches(
        $content,
        "(?ms)^relationship\s+(?<Name>[^\r\n]+)\r?\n(?<Body>.*?)(?=^relationship\s+|\z)"
    )

    $blocks = New-Object System.Collections.Generic.List[object]
    foreach ($match in $matches) {
        $blocks.Add([PSCustomObject]@{
            Name = $match.Groups["Name"].Value.Trim().Trim("'")
            Body = $match.Groups["Body"].Value
        })
    }

    return $blocks.ToArray()
}

function Invoke-PbiProjectArchitectureRules {
    param([Parameter(Mandatory = $true)]$Project)

    $results = New-Object System.Collections.Generic.List[object]
    $contract = Get-PbiArchitectureContract
    $coreProjectIds = @($contract.coreProjectIds)
    $relationshipsPath = Join-Path $Project.SemanticModelPath "definition/relationships.tmdl"
    $relationshipBlocks = @(Get-PbiRelationshipDefinitionBlocks -RelationshipsPath $relationshipsPath)

    foreach ($requirement in @($contract.relationshipRequirements)) {
        $relationshipBlock = @($relationshipBlocks | Where-Object { $_.Name -eq $requirement.relationshipName } | Select-Object -First 1)
        if (-not $relationshipBlock) {
            continue
        }

        $expectedCrossFilter = [regex]::Escape($requirement.crossFilteringBehavior)
        if ($relationshipBlock.Body -notmatch ("(?m)^\s*crossFilteringBehavior:\s*{0}\s*$" -f $expectedCrossFilter)) {
            $results.Add((New-PbiQualityResult -Scope "Project" -Target $Project.ProjectId -RuleId "architecture.relationship.crossfilter.required" -Severity "Error" -Message ("Relationship '{0}' must declare crossFilteringBehavior '{1}'." -f $requirement.relationshipName, $requirement.crossFilteringBehavior) -Path $relationshipsPath))
        }
    }

    if ($coreProjectIds -notcontains $Project.ProjectId) {
        return $results.ToArray()
    }

    $tableDirectory = Get-PbiTableDefinitionDirectoryForProject -Project $Project
    $projectTables = @((Get-PbiTmdlTableNamesFromDirectory -TableDirectory $tableDirectory) | Sort-Object -Unique)
    $allowedTables = @($contract.coreAllowedTables | Sort-Object -Unique)
    $unexpectedTables = @($projectTables | Where-Object { $allowedTables -notcontains $_ })

    foreach ($tableName in $unexpectedTables) {
        $results.Add((New-PbiQualityResult -Scope "Project" -Target $Project.ProjectId -RuleId "architecture.core-contract.table-allowed" -Severity "Error" -Message ("Core project contains non-core table '{0}'." -f $tableName) -Path $tableDirectory))
    }

    $missingTables = @($allowedTables | Where-Object { $projectTables -notcontains $_ })
    foreach ($tableName in $missingTables) {
        $results.Add((New-PbiQualityResult -Scope "Project" -Target $Project.ProjectId -RuleId "architecture.core-contract.table-required" -Severity "Error" -Message ("Core project is missing required core table '{0}'." -f $tableName) -Path $tableDirectory))
    }

    $state = Get-PbiInstalledModulesState -Project $Project
    try {
        Test-PbiInstalledModulesStateSchema -State $state -StatePath $Project.StateFilePath
    }
    catch {
        $results.Add((New-PbiQualityResult -Scope "Project" -Target $Project.ProjectId -RuleId "project.installed-state.valid" -Severity "Error" -Message $_.Exception.Message -Path $Project.StateFilePath))
    }

    if (@($state.installedModules).Count -gt 0) {
        $results.Add((New-PbiQualityResult -Scope "Project" -Target $Project.ProjectId -RuleId "architecture.core-contract.no-installed-modules" -Severity "Error" -Message "Core baseline project must not contain installed module metadata." -Path $Project.StateFilePath))
    }

    return $results.ToArray()
}

Export-ModuleMember -Function Invoke-PbiModuleArchitectureRules, Invoke-PbiProjectArchitectureRules
