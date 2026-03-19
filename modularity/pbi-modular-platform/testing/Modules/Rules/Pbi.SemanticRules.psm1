function Get-PbiLocalPathFindingsFromDirectory {
    param(
        [Parameter(Mandatory = $true)][string]$RootPath,
        [Parameter(Mandatory = $true)][string]$Scope,
        [Parameter(Mandatory = $true)][string]$Target
    )

    $results = New-Object System.Collections.Generic.List[object]
    $pathPattern = '(?i)"[A-Z]:\\'

    foreach ($file in (Get-ChildItem -Path $RootPath -Recurse -Filter "*.tmdl" -File -ErrorAction SilentlyContinue)) {
        if ($file.Name -eq "expressions.tmdl") {
            continue
        }

        $content = Get-Content -Path $file.FullName -Raw

        if ($content -match $pathPattern) {
            $results.Add((New-PbiQualityResult -Scope $Scope -Target $Target -RuleId "semantic.local-path.forbidden" -Severity "Error" -Message "Semantic definition contains a hardcoded local absolute path." -Path $file.FullName))
        }
    }

    return $results.ToArray()
}

function Get-PbiRootPathParameterFindings {
    param(
        [Parameter(Mandatory = $true)]$Project
    )

    $results = New-Object System.Collections.Generic.List[object]
    $expressionsPath = Get-PbiExpressionsPath -Project $Project

    if (-not (Test-Path $expressionsPath)) {
        return $results.ToArray()
    }

    $rootPathValue = Get-PbiRootPathParameterValue -Project $Project

    if ($rootPathValue -like "__SET_LOCAL_DATA_SOURCE_PATH__*") {
        $results.Add((New-PbiQualityResult -Scope "Project" -Target $Project.ProjectId -RuleId "semantic.root-path.placeholder.unresolved" -Severity "Warning" -Message "root_path still uses the source-control placeholder. Configure a local data source path before opening or refreshing in Power BI Desktop." -Path $expressionsPath))
        return $results.ToArray()
    }

    if (-not [System.IO.Path]::IsPathRooted($rootPathValue)) {
        $results.Add((New-PbiQualityResult -Scope "Project" -Target $Project.ProjectId -RuleId "semantic.root-path.absolute.required" -Severity "Error" -Message "root_path must resolve to an absolute local directory path." -Path $expressionsPath))
    }

    return $results.ToArray()
}

function Get-PbiTmdlLiteralEscapeFindingsFromText {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$Scope,
        [Parameter(Mandatory = $true)][string]$Target,
        [Parameter(Mandatory = $true)][string]$RuleId,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $results = New-Object System.Collections.Generic.List[object]
    $tokens = @('`t', '`r', '`n')
    $lines = $Text -split "\r?\n"

    for ($lineIndex = 0; $lineIndex -lt $lines.Count; $lineIndex++) {
        $line = [string]$lines[$lineIndex]
        $matchedTokens = @($tokens | Where-Object { $line.Contains($_) })
        if ($matchedTokens.Count -eq 0) {
            continue
        }

        $excerpt = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($excerpt)) {
            $excerpt = $line
        }

        if ($excerpt.Length -gt 140) {
            $excerpt = $excerpt.Substring(0, 140) + "..."
        }

        $results.Add((New-PbiQualityResult `
                -Scope $Scope `
                -Target $Target `
                -RuleId $RuleId `
                -Severity "Error" `
                -Message ("TMDL contains literal PowerShell escape sequence(s) {0} on line {1}: {2}" -f (($matchedTokens | Sort-Object -Unique) -join ", "), ($lineIndex + 1), $excerpt) `
                -Path $Path))
    }

    return $results.ToArray()
}

function Get-PbiTmdlLiteralEscapeFindingsFromDirectory {
    param(
        [Parameter(Mandatory = $true)][string]$RootPath,
        [Parameter(Mandatory = $true)][string]$Scope,
        [Parameter(Mandatory = $true)][string]$Target,
        [Parameter(Mandatory = $true)][string]$RuleId
    )

    $results = New-Object System.Collections.Generic.List[object]
    if (-not (Test-Path $RootPath)) {
        return $results.ToArray()
    }

    foreach ($file in (Get-ChildItem -Path $RootPath -Recurse -Filter "*.tmdl" -File -ErrorAction SilentlyContinue)) {
        $content = Get-Content -Path $file.FullName -Raw
        foreach ($issue in (Get-PbiTmdlLiteralEscapeFindingsFromText -Text $content -Scope $Scope -Target $Target -RuleId $RuleId -Path $file.FullName)) {
            $results.Add($issue)
        }
    }

    return $results.ToArray()
}

function Get-PbiUnresolvedBindingTokenFindingsFromText {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$Scope,
        [Parameter(Mandatory = $true)][string]$Target,
        [Parameter(Mandatory = $true)][string]$RuleId,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $results = New-Object System.Collections.Generic.List[object]
    $tokenPattern = "\{\{?binding(?:Label|Value|Table|Column|QueryRef):.+?\}\}?"
    $lines = $Text -split "\r?\n"

    for ($lineIndex = 0; $lineIndex -lt $lines.Count; $lineIndex++) {
        $line = [string]$lines[$lineIndex]
        $matches = [regex]::Matches($line, $tokenPattern)
        if ($matches.Count -eq 0) {
            continue
        }

        $tokens = @($matches | ForEach-Object { $_.Value } | Select-Object -Unique)
        $excerpt = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($excerpt)) {
            $excerpt = $line
        }

        if ($excerpt.Length -gt 160) {
            $excerpt = $excerpt.Substring(0, 160) + "..."
        }

        $results.Add((New-PbiQualityResult `
                -Scope $Scope `
                -Target $Target `
                -RuleId $RuleId `
                -Severity "Error" `
                -Message ("Unresolved binding token(s) found on line {0}: {1}" -f ($lineIndex + 1), ($tokens -join ", ")) `
                -Path $Path))
    }

    return $results.ToArray()
}

function Get-PbiUnresolvedBindingTokenFindingsFromDirectory {
    param(
        [Parameter(Mandatory = $true)][string]$RootPath,
        [Parameter(Mandatory = $true)][string]$Scope,
        [Parameter(Mandatory = $true)][string]$Target,
        [Parameter(Mandatory = $true)][string]$RuleId
    )

    $results = New-Object System.Collections.Generic.List[object]
    if (-not (Test-Path $RootPath)) {
        return $results.ToArray()
    }

    foreach ($file in (Get-ChildItem -Path $RootPath -Recurse -Filter "*.tmdl" -File -ErrorAction SilentlyContinue)) {
        $content = Get-Content -Path $file.FullName -Raw
        foreach ($issue in (Get-PbiUnresolvedBindingTokenFindingsFromText -Text $content -Scope $Scope -Target $Target -RuleId $RuleId -Path $file.FullName)) {
            $results.Add($issue)
        }
    }

    return $results.ToArray()
}

function Get-PbiModuleRenderValidationMappings {
    param([Parameter(Mandatory = $true)]$Manifest)

    $resolvedMappings = ConvertTo-PbiResolvedMappings -Mappings (Get-PbiBindingContractDefaultMappings -Manifest $Manifest)
    $contract = Get-PbiModuleBindingContract -Manifest $Manifest

    foreach ($role in @($contract.roles)) {
        if ($role.kind -notin @("measure", "column")) {
            continue
        }

        $shouldInclude = [bool]$role.required
        if (-not $shouldInclude -and -not [string]::IsNullOrWhiteSpace([string]$role.collectionId)) {
            $defaultVisibleCount = if ($null -ne $role.collectionDefaultVisibleCount) { [int]$role.collectionDefaultVisibleCount } else { 0 }
            $collectionOrdinal = if ($null -ne $role.collectionOrdinal) { [int]$role.collectionOrdinal } else { 0 }
            $shouldInclude = ($collectionOrdinal -gt 0 -and $collectionOrdinal -le $defaultVisibleCount)
        }

        if (-not $shouldInclude) {
            continue
        }

        $sectionName = if ($role.kind -eq "measure") { "coreMeasures" } else { "coreColumns" }
        $section = Get-PbiResolvedMappingSection -ResolvedMappings $resolvedMappings -SectionName $sectionName
        $currentValue = if ($section.Contains($role.bindingKey)) { [string]$section[$role.bindingKey] } else { "" }
        if ([string]::IsNullOrWhiteSpace($currentValue)) {
            $section[$role.bindingKey] = [string]$role.bindingKey
        }
    }

    return $resolvedMappings
}

function New-PbiSemanticRenderValidationProject {
    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("pbi-semantic-render-validation-" + [guid]::NewGuid().ToString("N"))
    $semanticModelPath = Join-Path $tempRoot "RenderValidation.SemanticModel"
    Ensure-PbiDirectory -Path (Join-Path $semanticModelPath "definition/tables")

    return [PSCustomObject]@{
        ProjectRoot       = $tempRoot
        SemanticModelPath = $semanticModelPath
    }
}

function Get-PbiRenderedModuleSemanticFindings {
    param([Parameter(Mandatory = $true)]$Module)

    $results = New-Object System.Collections.Generic.List[object]
    $renderingStrategy = Get-PbiModuleRenderingStrategy -Manifest $Module.Manifest
    if ($renderingStrategy -eq "static") {
        return $results.ToArray()
    }

    $validationProject = $null
    try {
        $validationProject = New-PbiSemanticRenderValidationProject
        $validationMappings = Get-PbiModuleRenderValidationMappings -Manifest $Module.Manifest
        $renderedAssets = @(Get-PbiRenderedModuleSemanticAssets -Project $validationProject -Module $Module -Manifest $Module.Manifest -ResolvedMappings $validationMappings)

        foreach ($asset in $renderedAssets) {
            $renderedPath = ("rendered::{0}.tmdl" -f $asset.TableName)
            foreach ($issue in (Get-PbiTmdlLiteralEscapeFindingsFromText -Text ([string]$asset.SourceContent) -Scope "Module" -Target $Module.ModuleId -RuleId "semantic.tmdl.rendered.literal-escape.forbidden" -Path $renderedPath)) {
                $results.Add($issue)
            }

            foreach ($issue in (Get-PbiUnresolvedBindingTokenFindingsFromText -Text ([string]$asset.SourceContent) -Scope "Module" -Target $Module.ModuleId -RuleId "semantic.binding-token.unresolved" -Path $renderedPath)) {
                $results.Add($issue)
            }
        }
    }
    catch {
        $results.Add((New-PbiQualityResult `
                -Scope "Module" `
                -Target $Module.ModuleId `
                -RuleId "semantic.tmdl.render.succeeds" `
                -Severity "Error" `
                -Message ("Dynamic semantic assets could not be rendered for validation: {0}" -f $_.Exception.Message) `
                -Path $Module.PackageRoot))
    }
    finally {
        if ($validationProject -and (Test-Path $validationProject.ProjectRoot)) {
            Remove-Item -Path $validationProject.ProjectRoot -Recurse -Force
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

    foreach ($result in (Get-PbiTmdlLiteralEscapeFindingsFromDirectory -RootPath $tableDirectory -Scope "Module" -Target $Module.ModuleId -RuleId "semantic.tmdl.literal-escape.forbidden")) {
        $results.Add($result)
    }

    foreach ($result in (Get-PbiRenderedModuleSemanticFindings -Module $Module)) {
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

    foreach ($result in (Get-PbiTmdlLiteralEscapeFindingsFromDirectory -RootPath (Join-Path $Project.SemanticModelPath "definition") -Scope "Project" -Target $Project.ProjectId -RuleId "semantic.tmdl.literal-escape.forbidden")) {
        $results.Add($result)
    }

    foreach ($result in (Get-PbiUnresolvedBindingTokenFindingsFromDirectory -RootPath (Join-Path $Project.SemanticModelPath "definition") -Scope "Project" -Target $Project.ProjectId -RuleId "semantic.binding-token.unresolved")) {
        $results.Add($result)
    }

    foreach ($result in (Get-PbiRootPathParameterFindings -Project $Project)) {
        $results.Add($result)
    }

    return $results.ToArray()
}

Export-ModuleMember -Function Invoke-PbiModuleSemanticRules, Invoke-PbiProjectSemanticRules
