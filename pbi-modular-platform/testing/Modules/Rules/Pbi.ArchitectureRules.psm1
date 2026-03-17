function Invoke-PbiModuleArchitectureRules {
    param([Parameter(Mandatory = $true)]$Module)

    $results = New-Object System.Collections.Generic.List[object]
    $contract = Get-PbiArchitectureContract
    $coreTableSet = @($contract.coreAllowedTables)

    foreach ($tableName in @($Module.Manifest.provides.semanticTables)) {
        if ($coreTableSet -contains $tableName) {
            $results.Add((New-PbiQualityResult -Scope "Module" -Target $Module.ModuleId -RuleId "architecture.module.core-table.forbidden" -Severity "Error" -Message ("Module declares semantic table '{0}', but that table belongs to the semantic core contract." -f $tableName) -Path (Join-Path $Module.PackageRoot "manifest.json")))
        }
    }

    return $results.ToArray()
}

function Invoke-PbiProjectArchitectureRules {
    param([Parameter(Mandatory = $true)]$Project)

    $results = New-Object System.Collections.Generic.List[object]
    $contract = Get-PbiArchitectureContract
    $coreProjectIds = @($contract.coreProjectIds)

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
    if (@($state.installedModules).Count -gt 0) {
        $results.Add((New-PbiQualityResult -Scope "Project" -Target $Project.ProjectId -RuleId "architecture.core-contract.no-installed-modules" -Severity "Error" -Message "Core baseline project must not contain installed module metadata." -Path $Project.StateFilePath))
    }

    return $results.ToArray()
}

Export-ModuleMember -Function Invoke-PbiModuleArchitectureRules, Invoke-PbiProjectArchitectureRules
