function Invoke-PbiModuleManifestRules {
    param([Parameter(Mandatory = $true)]$Module)

    $results = New-Object System.Collections.Generic.List[object]
    $scope = "Module"
    $target = $Module.ModuleId

    if (-not (Test-Path $Module.PackageRoot)) {
        $results.Add((New-PbiQualityResult -Scope $scope -Target $target -RuleId "module.package-root.exists" -Severity "Error" -Message "Package root does not exist." -Path $Module.PackageRoot))
        return $results.ToArray()
    }

    if (-not (Test-Path $Module.ManifestPath)) {
        $results.Add((New-PbiQualityResult -Scope $scope -Target $target -RuleId "module.manifest.exists" -Severity "Error" -Message "manifest.json is missing." -Path $Module.ManifestPath))
        return $results.ToArray()
    }

    try {
        Test-PbiModuleManifest -Manifest $Module.Manifest -ManifestPath $Module.ManifestPath
    }
    catch {
        $results.Add((New-PbiQualityResult -Scope $scope -Target $target -RuleId "module.manifest.valid" -Severity "Error" -Message $_.Exception.Message -Path $Module.ManifestPath))
    }

    $semanticRoot = Join-Path $Module.PackageRoot "semantic"
    if (-not (Test-Path $semanticRoot)) {
        $results.Add((New-PbiQualityResult -Scope $scope -Target $target -RuleId "module.semantic-root.exists" -Severity "Error" -Message "semantic folder is missing." -Path $semanticRoot))
    }

    foreach ($tableName in @($Module.Manifest.provides.semanticTables)) {
        $tablePath = Join-Path $semanticRoot ($tableName + ".tmdl")
        if (-not (Test-Path $tablePath)) {
            $results.Add((New-PbiQualityResult -Scope $scope -Target $target -RuleId "module.semantic-table.exists" -Severity "Error" -Message ("Declared semantic table '{0}' is missing." -f $tableName) -Path $tablePath))
        }
    }

    if ($Module.Manifest.provides.reportPage) {
        $reportRoot = Join-Path $Module.PackageRoot "report"
        $pageJsonPath = Join-Path $reportRoot "page.json"

        if (-not (Test-Path $reportRoot)) {
            $results.Add((New-PbiQualityResult -Scope $scope -Target $target -RuleId "module.report-root.exists" -Severity "Error" -Message "report folder is missing." -Path $reportRoot))
        }
        elseif (-not (Test-Path $pageJsonPath)) {
            $results.Add((New-PbiQualityResult -Scope $scope -Target $target -RuleId "module.report-page.exists" -Severity "Error" -Message "page.json is missing from report assets." -Path $pageJsonPath))
        }
    }

    return $results.ToArray()
}

Export-ModuleMember -Function Invoke-PbiModuleManifestRules
