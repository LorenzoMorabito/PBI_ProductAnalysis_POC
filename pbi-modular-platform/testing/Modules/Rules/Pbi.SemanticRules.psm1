function Get-PbiLocalPathFindingsFromDirectory {
    param(
        [Parameter(Mandatory = $true)][string]$RootPath,
        [Parameter(Mandatory = $true)][string]$Scope,
        [Parameter(Mandatory = $true)][string]$Target
    )

    $results = New-Object System.Collections.Generic.List[object]
    $pathPattern = '(?i)"[A-Z]:\\'

    foreach ($file in (Get-ChildItem -Path $RootPath -Recurse -Filter "*.tmdl" -File -ErrorAction SilentlyContinue)) {
        $content = Get-Content -Path $file.FullName -Raw

        if ($content -match $pathPattern) {
            $results.Add((New-PbiQualityResult -Scope $Scope -Target $Target -RuleId "semantic.local-path.forbidden" -Severity "Error" -Message "Semantic definition contains a hardcoded local absolute path." -Path $file.FullName))
        }
    }

    return $results.ToArray()
}

function Invoke-PbiModuleSemanticRules {
    param([Parameter(Mandatory = $true)]$Module)

    $results = New-Object System.Collections.Generic.List[object]
    $tableDirectory = Join-Path $Module.PackageRoot "semantic"
    $measureOccurrences = Get-PbiMeasureOccurrencesFromDirectory -TableDirectory $tableDirectory
    $duplicateMeasureGroups = @($measureOccurrences | Group-Object Name | Where-Object { $_.Count -gt 1 })

    foreach ($duplicateGroup in $duplicateMeasureGroups) {
        $locations = @($duplicateGroup.Group | ForEach-Object { "{0} ({1})" -f $_.TableName, [System.IO.Path]::GetFileName($_.Path) })
        $results.Add((New-PbiQualityResult -Scope "Module" -Target $Module.ModuleId -RuleId "semantic.measure-name.unique" -Severity "Error" -Message ("Measure '{0}' is defined multiple times: {1}" -f $duplicateGroup.Name, ($locations -join ", ")) -Path $tableDirectory))
    }

    foreach ($result in (Get-PbiLocalPathFindingsFromDirectory -RootPath $tableDirectory -Scope "Module" -Target $Module.ModuleId)) {
        $results.Add($result)
    }

    return $results.ToArray()
}

function Invoke-PbiProjectSemanticRules {
    param([Parameter(Mandatory = $true)]$Project)

    $results = New-Object System.Collections.Generic.List[object]
    $tableDirectory = Get-PbiTableDefinitionDirectoryForProject -Project $Project
    $measureOccurrences = Get-PbiMeasureOccurrencesFromDirectory -TableDirectory $tableDirectory
    $duplicateMeasureGroups = @($measureOccurrences | Group-Object Name | Where-Object { $_.Count -gt 1 })

    foreach ($duplicateGroup in $duplicateMeasureGroups) {
        $locations = @($duplicateGroup.Group | ForEach-Object { "{0} ({1})" -f $_.TableName, [System.IO.Path]::GetFileName($_.Path) })
        $results.Add((New-PbiQualityResult -Scope "Project" -Target $Project.ProjectId -RuleId "semantic.measure-name.unique" -Severity "Error" -Message ("Measure '{0}' is defined multiple times: {1}" -f $duplicateGroup.Name, ($locations -join ", ")) -Path $tableDirectory))
    }

    foreach ($result in (Get-PbiLocalPathFindingsFromDirectory -RootPath (Join-Path $Project.SemanticModelPath "definition") -Scope "Project" -Target $Project.ProjectId)) {
        $results.Add($result)
    }

    return $results.ToArray()
}

Export-ModuleMember -Function Invoke-PbiModuleSemanticRules, Invoke-PbiProjectSemanticRules
