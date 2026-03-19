function Get-PbiTmdlIdentifier {
    param([Parameter(Mandatory = $true)][string]$Name)

    if ($Name -match "^[A-Za-z_][A-Za-z0-9_]*$") {
        return $Name
    }

    return "'" + $Name.Replace("'", "''") + "'"
}

function Get-PbiExpressionsPath {
    param([Parameter(Mandatory = $true)]$Project)

    return (Join-Path $Project.SemanticModelPath "definition/expressions.tmdl")
}

function Get-PbiRootPathParameterValue {
    param([Parameter(Mandatory = $true)]$Project)

    $expressionsPath = Get-PbiExpressionsPath -Project $Project
    $content = Get-Content -Path $expressionsPath -Raw
    $match = [regex]::Match($content, 'expression\s+root_path\s*=\s*"(?<Value>[^"]*)"')

    if (-not $match.Success) {
        throw "root_path expression was not found in '$expressionsPath'."
    }

    return $match.Groups["Value"].Value
}

function Set-PbiRootPathParameterValue {
    param(
        [Parameter(Mandatory = $true)]$Project,
        [Parameter(Mandatory = $true)][string]$DataSourcePath
    )

    if (-not [System.IO.Path]::IsPathRooted($DataSourcePath)) {
        throw "DataSourcePath must be an absolute path."
    }

    if (-not (Test-Path $DataSourcePath -PathType Container)) {
        throw "DataSourcePath '$DataSourcePath' does not exist or is not a directory."
    }

    $resolvedPath = (Resolve-Path $DataSourcePath).Path
    if (-not $resolvedPath.EndsWith("\")) {
        $resolvedPath += "\"
    }

    $expressionsPath = Get-PbiExpressionsPath -Project $Project
    $content = Get-Content -Path $expressionsPath -Raw
    $updatedContent = [regex]::Replace(
        $content,
        'expression\s+root_path\s*=\s*"(?<Value>[^"]*)"',
        ('expression root_path = "' + $resolvedPath + '"'),
        1
    )

    if ($updatedContent -eq $content) {
        throw "Unable to update root_path in '$expressionsPath'."
    }

    Write-PbiUtf8File -Path $expressionsPath -Content $updatedContent
    return $resolvedPath
}

function Get-PbiTableDefinitionDirectory {
    param([Parameter(Mandatory = $true)]$Project)

    return (Join-Path $Project.SemanticModelPath "definition/tables")
}

function Get-PbiTableDefinitionPath {
    param(
        [Parameter(Mandatory = $true)]$Project,
        [Parameter(Mandatory = $true)][string]$TableName
    )

    return (Join-Path (Get-PbiTableDefinitionDirectory -Project $Project) ($TableName + ".tmdl"))
}

function Get-PbiModelPath {
    param([Parameter(Mandatory = $true)]$Project)

    return (Join-Path $Project.SemanticModelPath "definition/model.tmdl")
}

function Test-PbiMeasureExists {
    param(
        [Parameter(Mandatory = $true)]$Project,
        [Parameter(Mandatory = $true)][string]$MeasureName
    )

    $escapedMeasureName = [regex]::Escape($MeasureName)
    $measurePattern = "(?m)^\s*measure\s+('{0}'|{0})(?=\s*=|\s*$)" -f $escapedMeasureName
    $tableDirectory = Get-PbiTableDefinitionDirectory -Project $Project

    return [bool](Get-ChildItem -Path $tableDirectory -Filter "*.tmdl" |
        Select-String -Pattern $measurePattern -SimpleMatch:$false | Select-Object -First 1)
}

function Get-PbiMeasureNamesFromTmdlContent {
    param([Parameter(Mandatory = $true)][string]$Content)

    $pattern = "(?m)^\s*measure\s+(?:'((?:[^']|'')+)'|([A-Za-z_][A-Za-z0-9_]*))(?=\s*=|\s*$)"
    $matches = [regex]::Matches($Content, $pattern)
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

function Get-PbiProjectMeasureNames {
    param(
        [Parameter(Mandatory = $true)]$Project,
        [string[]]$ExcludeTables = @()
    )

    $tableDirectory = Get-PbiTableDefinitionDirectory -Project $Project
    $measureNames = New-Object System.Collections.Generic.List[string]

    foreach ($tablePath in (Get-ChildItem -Path $tableDirectory -Filter "*.tmdl")) {
        $tableName = [System.IO.Path]::GetFileNameWithoutExtension($tablePath.Name)

        if ($ExcludeTables -contains $tableName) {
            continue
        }

        $content = Get-Content -Path $tablePath.FullName -Raw
        foreach ($measureName in (Get-PbiMeasureNamesFromTmdlContent -Content $content)) {
            $measureNames.Add($measureName)
        }
    }

    return @($measureNames | Select-Object -Unique)
}

function Get-PbiModuleMeasureNames {
    param(
        [Parameter(Mandatory = $true)]$Module,
        [Parameter(Mandatory = $true)]$Manifest
    )

    $sourceSemanticPath = Join-Path $Module.PackageRoot "semantic"
    $measureNames = New-Object System.Collections.Generic.List[string]

    foreach ($tableName in @($Manifest.provides.semanticTables)) {
        $sourcePath = Join-Path $sourceSemanticPath ($tableName + ".tmdl")
        $content = Get-Content -Path $sourcePath -Raw

        foreach ($measureName in (Get-PbiMeasureNamesFromTmdlContent -Content $content)) {
            $measureNames.Add($measureName)
        }
    }

    return @($measureNames | Select-Object -Unique)
}

function Test-PbiModuleMeasureConflicts {
    param(
        [Parameter(Mandatory = $true)]$Project,
        [Parameter(Mandatory = $true)]$Module,
        [Parameter(Mandatory = $true)]$Manifest,
        $ResolvedMappings
    )

    if (@($Manifest.provides.semanticTables).Count -eq 0) {
        return [PSCustomObject]@{
            HasConflicts = $false
            Conflicts    = @()
        }
    }

    $existingMeasureNames = Get-PbiProjectMeasureNames -Project $Project -ExcludeTables @($Manifest.provides.semanticTables)
    $moduleMeasureNames = if ($ResolvedMappings) {
        @((Get-PbiModuleSemanticObjectSummary -Module $Module -Manifest $Manifest -Project $Project -ResolvedMappings $ResolvedMappings).measures)
    }
    else {
        Get-PbiModuleMeasureNames -Module $Module -Manifest $Manifest
    }
    $conflicts = @($moduleMeasureNames | Where-Object { $existingMeasureNames -contains $_ } | Sort-Object -Unique)

    return [PSCustomObject]@{
        HasConflicts = ($conflicts.Count -gt 0)
        Conflicts    = $conflicts
    }
}

function Test-PbiColumnExists {
    param(
        [Parameter(Mandatory = $true)]$Project,
        [Parameter(Mandatory = $true)][string]$ColumnReference
    )

    if ($ColumnReference -notmatch "^(?<Table>.+?)\[(?<Column>.+)\]$") {
        throw "Column reference '$ColumnReference' is not in the expected Table[Column] format."
    }

    $tableName = $Matches.Table
    $columnName = $Matches.Column
    $tableDirectory = Get-PbiTableDefinitionDirectory -Project $Project
    $candidatePath = Join-Path $tableDirectory ($tableName + ".tmdl")

    if (-not (Test-Path $candidatePath)) {
        $escapedTableName = [regex]::Escape($tableName)
        $tablePattern = "(?m)^\s*table\s+('{0}'|{0})(?=\s*$|\s)" -f $escapedTableName
        $candidatePath = Get-ChildItem -Path $tableDirectory -Filter "*.tmdl" |
            Select-String -Pattern $tablePattern -SimpleMatch:$false |
            Select-Object -First 1 |
            ForEach-Object { $_.Path }
    }

    if (-not $candidatePath) {
        return $false
    }

    $escapedColumnName = [regex]::Escape($columnName)
    $columnPattern = "(?m)^\s*column\s+('{0}'|{0})(?=\s*$|\s)" -f $escapedColumnName

    return [bool](Select-String -Path $candidatePath -Pattern $columnPattern -SimpleMatch:$false | Select-Object -First 1)
}

function Test-PbiModuleRequirements {
    param(
        [Parameter(Mandatory = $true)]$Project,
        [Parameter(Mandatory = $true)]$Manifest,
        $ResolvedMappings
    )

    $missingMeasures = New-Object System.Collections.Generic.List[string]
    $missingColumns = New-Object System.Collections.Generic.List[string]
    $normalizedMappings = ConvertTo-PbiResolvedMappings -Mappings $ResolvedMappings
    $contract = Get-PbiModuleBindingContract -Manifest $Manifest
    $measureRequirements = @()
    $columnRequirements = @()

    if (@($contract.collections).Count -gt 0) {
        foreach ($role in @($contract.roles)) {
            $sectionName = if ($role.kind -eq "measure") { "coreMeasures" } else { "coreColumns" }
            $mappingSection = Get-PbiResolvedMappingSection -ResolvedMappings $normalizedMappings -SectionName $sectionName
            $hasMapping = [bool]($mappingSection -and $mappingSection.Contains($role.bindingKey))
            $resolvedValue = if ($hasMapping) { [string]$mappingSection[$role.bindingKey] } else { "" }

            if ($hasMapping -and -not [string]::IsNullOrWhiteSpace($resolvedValue)) {
                if ($role.kind -eq "measure") {
                    $measureRequirements += [ordered]@{
                        source = [string]$role.bindingKey
                        target = $resolvedValue
                    }
                }
                else {
                    $columnRequirements += [ordered]@{
                        source = [string]$role.bindingKey
                        target = $resolvedValue
                    }
                }
            }
            elseif ($role.required) {
                if ($role.kind -eq "measure") {
                    $measureRequirements += [ordered]@{
                        source = [string]$role.bindingKey
                        target = [string]$role.bindingKey
                    }
                }
                else {
                    $columnRequirements += [ordered]@{
                        source = [string]$role.bindingKey
                        target = [string]$role.bindingKey
                    }
                }
            }
        }
    }
    else {
        foreach ($measureName in @($Manifest.requires.coreMeasures)) {
            $measureRequirements += [ordered]@{
                source = $measureName
                target = if ($normalizedMappings.coreMeasures.Contains($measureName)) { [string]$normalizedMappings.coreMeasures[$measureName] } else { $measureName }
            }
        }

        foreach ($columnReference in @($Manifest.requires.coreColumns)) {
            $columnRequirements += [ordered]@{
                source = $columnReference
                target = if ($normalizedMappings.coreColumns.Contains($columnReference)) { [string]$normalizedMappings.coreColumns[$columnReference] } else { $columnReference }
            }
        }
    }

    foreach ($measureRequirement in @($measureRequirements)) {
        if (-not (Test-PbiMeasureExists -Project $Project -MeasureName $measureRequirement.target)) {
            if ($measureRequirement.source -eq $measureRequirement.target) {
                $missingMeasures.Add([string]$measureRequirement.source)
            }
            else {
                $missingMeasures.Add(("{0} -> {1}" -f $measureRequirement.source, $measureRequirement.target))
            }
        }
    }

    foreach ($columnRequirement in @($columnRequirements)) {
        if (-not (Test-PbiColumnExists -Project $Project -ColumnReference $columnRequirement.target)) {
            if ($columnRequirement.source -eq $columnRequirement.target) {
                $missingColumns.Add([string]$columnRequirement.source)
            }
            else {
                $missingColumns.Add(("{0} -> {1}" -f $columnRequirement.source, $columnRequirement.target))
            }
        }
    }

    return [PSCustomObject]@{
        IsValid         = ($missingMeasures.Count -eq 0 -and $missingColumns.Count -eq 0)
        MissingMeasures = @($missingMeasures)
        MissingColumns  = @($missingColumns)
    }
}

function Test-PbiSemanticAssetsPresent {
    param(
        [Parameter(Mandatory = $true)]$Project,
        [Parameter(Mandatory = $true)]$Manifest
    )

    if (@($Manifest.provides.semanticTables).Count -eq 0) {
        return $true
    }

    $tableDirectory = Get-PbiTableDefinitionDirectory -Project $Project

    foreach ($tableName in @($Manifest.provides.semanticTables)) {
        $tablePath = Join-Path $tableDirectory ($tableName + ".tmdl")

        if (-not (Test-Path $tablePath)) {
            return $false
        }
    }

    return $true
}

function Update-PbiModelQueryOrder {
    param(
        [Parameter(Mandatory = $true)][string]$ModelContent,
        [Parameter(Mandatory = $true)][string[]]$TableNames
    )

    $queryOrderPattern = "annotation PBI_QueryOrder = (\[.*?\])"
    $match = [regex]::Match($ModelContent, $queryOrderPattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)

    if (-not $match.Success) {
        throw "PBI_QueryOrder annotation was not found in model.tmdl."
    }

    $currentOrder = @(ConvertFrom-PbiJsonText -Text $match.Groups[1].Value)

    foreach ($tableName in $TableNames) {
        if ($currentOrder -notcontains $tableName) {
            $currentOrder += $tableName
        }
    }

    $updatedOrderJson = ConvertTo-PbiJsonText -InputObject $currentOrder -Compress

    return [regex]::Replace(
        $ModelContent,
        $queryOrderPattern,
        ("annotation PBI_QueryOrder = " + $updatedOrderJson),
        [System.Text.RegularExpressions.RegexOptions]::Singleline
    )
}

function Update-PbiModelTableReferences {
    param(
        [Parameter(Mandatory = $true)][string]$ModelContent,
        [Parameter(Mandatory = $true)][string[]]$TableNames
    )

    $missingRefLines = New-Object System.Collections.Generic.List[string]

    foreach ($tableName in $TableNames) {
        $identifier = Get-PbiTmdlIdentifier -Name $tableName
        $refPattern = "(?m)^\s*ref table {0}\s*$" -f [regex]::Escape($identifier)

        if (-not ([regex]::IsMatch($ModelContent, $refPattern))) {
            $missingRefLines.Add("ref table " + $identifier)
        }
    }

    if ($missingRefLines.Count -eq 0) {
        return $ModelContent
    }

    $culturePattern = "(?m)^ref cultureInfo .+$"
    $refBlock = (($missingRefLines -join "`r`n") + "`r`n")

    if ([regex]::IsMatch($ModelContent, $culturePattern)) {
        return [regex]::Replace($ModelContent, $culturePattern, ($refBlock + '$0'), 1)
    }

    return ($ModelContent.TrimEnd() + "`r`n`r`n" + ($missingRefLines -join "`r`n") + "`r`n")
}

function Get-PbiModuleSemanticFileMappings {
    param(
        [Parameter(Mandatory = $true)]$Project,
        [Parameter(Mandatory = $true)]$Module,
        [Parameter(Mandatory = $true)]$Manifest,
        $ResolvedMappings
    )

    $renderedMappings = @(Get-PbiRenderedModuleSemanticAssets -Project $Project -Module $Module -Manifest $Manifest -ResolvedMappings $ResolvedMappings)
    if ($renderedMappings.Count -gt 0) {
        return $renderedMappings
    }

    $sourceSemanticPath = Join-Path $Module.PackageRoot "semantic"
    $mappings = New-Object System.Collections.Generic.List[object]

    foreach ($tableName in @($Manifest.provides.semanticTables)) {
        $sourcePath = Join-Path $sourceSemanticPath ($tableName + ".tmdl")
        $destinationPath = Get-PbiTableDefinitionPath -Project $Project -TableName $tableName
        $mappings.Add([PSCustomObject]@{
            TableName        = $tableName
            SourcePath       = $sourcePath
            DestinationPath  = $destinationPath
            RelativePath     = (Get-PbiRelativePath -BasePath $Project.ProjectRoot -Path $destinationPath)
        })
    }

    return $mappings.ToArray()
}

function Get-PbiModuleSemanticObjectSummary {
    param(
        [Parameter(Mandatory = $true)]$Module,
        [Parameter(Mandatory = $true)]$Manifest,
        $Project,
        $ResolvedMappings
    )

    if ($Project -and $ResolvedMappings) {
        $measureNames = New-Object System.Collections.Generic.List[string]
        $fileMappings = @(Get-PbiModuleSemanticFileMappings -Project $Project -Module $Module -Manifest $Manifest -ResolvedMappings $ResolvedMappings)
        foreach ($mapping in $fileMappings) {
            $content = if ($mapping.SourceContent) { [string]$mapping.SourceContent } else { Get-Content -Path $mapping.SourcePath -Raw }
            foreach ($measureName in (Get-PbiMeasureNamesFromTmdlContent -Content $content)) {
                $measureNames.Add($measureName)
            }
        }

        return [ordered]@{
            tables   = @($Manifest.provides.semanticTables)
            measures = @($measureNames | Select-Object -Unique)
        }
    }

    return [ordered]@{
        tables   = @($Manifest.provides.semanticTables)
        measures = @(Get-PbiModuleMeasureNames -Module $Module -Manifest $Manifest)
    }
}

function Install-PbiSemanticAssets {
    param(
        [Parameter(Mandatory = $true)]$Project,
        [Parameter(Mandatory = $true)]$Module,
        [Parameter(Mandatory = $true)]$Manifest,
        $ResolvedMappings,
        [switch]$Force
    )

    if (@($Manifest.provides.semanticTables).Count -eq 0) {
        return [PSCustomObject]@{
            FilesTouched         = @()
            SemanticObjectsAdded = [ordered]@{
                tables   = @()
                measures = @()
            }
        }
    }

    $sourceSemanticPath = Join-Path $Module.PackageRoot "semantic"
    $tableDirectory = Get-PbiTableDefinitionDirectory -Project $Project
    Ensure-PbiDirectory -Path $tableDirectory
    $measureConflicts = Test-PbiModuleMeasureConflicts -Project $Project -Module $Module -Manifest $Manifest -ResolvedMappings $ResolvedMappings
    $filesTouched = New-Object System.Collections.Generic.List[string]
    $fileMappings = @(Get-PbiModuleSemanticFileMappings -Project $Project -Module $Module -Manifest $Manifest -ResolvedMappings $ResolvedMappings)

    if ($measureConflicts.HasConflicts) {
        throw ("Module '{0}' defines measure names already present in project '{1}': {2}" -f
            $Module.ModuleId,
            $Project.ProjectId,
            ($measureConflicts.Conflicts -join ", "))
    }

    foreach ($mapping in $fileMappings) {
        $tableName = $mapping.TableName
        $destinationPath = $mapping.DestinationPath

        if ((Test-Path $destinationPath) -and -not $Force) {
            throw "Semantic table '$tableName' already exists at '$destinationPath'. Use -Force to overwrite."
        }

        $renderedContent = if ($mapping.SourceContent) {
            [string]$mapping.SourceContent
        }
        else {
            $sourceContent = Get-Content -Path $mapping.SourcePath -Raw
            Convert-PbiTextWithResolvedMappings -Text $sourceContent -ResolvedMappings $ResolvedMappings
        }
        Write-PbiUtf8File -Path $destinationPath -Content $renderedContent
        $filesTouched.Add((Get-PbiRelativePath -BasePath $Project.ProjectRoot -Path $destinationPath))
    }

    $modelPath = Get-PbiModelPath -Project $Project
    $modelContent = Get-Content $modelPath -Raw
    $modelContent = Update-PbiModelQueryOrder -ModelContent $modelContent -TableNames @($Manifest.provides.semanticTables)
    $modelContent = Update-PbiModelTableReferences -ModelContent $modelContent -TableNames @($Manifest.provides.semanticTables)
    Write-PbiUtf8File -Path $modelPath -Content $modelContent
    $filesTouched.Add((Get-PbiRelativePath -BasePath $Project.ProjectRoot -Path $modelPath))

    return [PSCustomObject]@{
        FilesTouched         = @($filesTouched | Sort-Object -Unique)
        SemanticObjectsAdded = (Get-PbiModuleSemanticObjectSummary -Module $Module -Manifest $Manifest -Project $Project -ResolvedMappings $ResolvedMappings)
    }
}

Export-ModuleMember -Function Get-PbiTmdlIdentifier, Get-PbiExpressionsPath, Get-PbiRootPathParameterValue, Set-PbiRootPathParameterValue, Get-PbiTableDefinitionPath, Get-PbiModelPath, Test-PbiMeasureExists, Test-PbiColumnExists, Test-PbiModuleRequirements, Test-PbiSemanticAssetsPresent, Get-PbiModuleSemanticFileMappings, Get-PbiModuleSemanticObjectSummary, Install-PbiSemanticAssets, Test-PbiModuleMeasureConflicts
