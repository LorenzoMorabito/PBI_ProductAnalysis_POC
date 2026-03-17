function Get-PbiTmdlIdentifier {
    param([Parameter(Mandatory = $true)][string]$Name)

    if ($Name -match "^[A-Za-z_][A-Za-z0-9_]*$") {
        return $Name
    }

    return "'" + $Name.Replace("'", "''") + "'"
}

function Get-PbiTableDefinitionDirectory {
    param([Parameter(Mandatory = $true)]$Project)

    return (Join-Path $Project.SemanticModelPath "definition/tables")
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
        [Parameter(Mandatory = $true)]$Manifest
    )

    $missingMeasures = New-Object System.Collections.Generic.List[string]
    $missingColumns = New-Object System.Collections.Generic.List[string]

    foreach ($measureName in @($Manifest.requires.coreMeasures)) {
        if (-not (Test-PbiMeasureExists -Project $Project -MeasureName $measureName)) {
            $missingMeasures.Add($measureName)
        }
    }

    foreach ($columnReference in @($Manifest.requires.coreColumns)) {
        if (-not (Test-PbiColumnExists -Project $Project -ColumnReference $columnReference)) {
            $missingColumns.Add($columnReference)
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

    $currentOrder = @($match.Groups[1].Value | ConvertFrom-Json)

    foreach ($tableName in $TableNames) {
        if ($currentOrder -notcontains $tableName) {
            $currentOrder += $tableName
        }
    }

    $updatedOrderJson = $currentOrder | ConvertTo-Json -Compress

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

function Install-PbiSemanticAssets {
    param(
        [Parameter(Mandatory = $true)]$Project,
        [Parameter(Mandatory = $true)]$Module,
        [Parameter(Mandatory = $true)]$Manifest,
        [switch]$Force
    )

    $sourceSemanticPath = Join-Path $Module.PackageRoot "semantic"
    $tableDirectory = Get-PbiTableDefinitionDirectory -Project $Project
    Ensure-PbiDirectory -Path $tableDirectory

    foreach ($tableName in @($Manifest.provides.semanticTables)) {
        $sourcePath = Join-Path $sourceSemanticPath ($tableName + ".tmdl")
        $destinationPath = Join-Path $tableDirectory ($tableName + ".tmdl")

        if ((Test-Path $destinationPath) -and -not $Force) {
            throw "Semantic table '$tableName' already exists at '$destinationPath'. Use -Force to overwrite."
        }

        Copy-Item -Path $sourcePath -Destination $destinationPath -Force
    }

    $modelPath = Get-PbiModelPath -Project $Project
    $modelContent = Get-Content $modelPath -Raw
    $modelContent = Update-PbiModelQueryOrder -ModelContent $modelContent -TableNames @($Manifest.provides.semanticTables)
    $modelContent = Update-PbiModelTableReferences -ModelContent $modelContent -TableNames @($Manifest.provides.semanticTables)
    Set-Content -Path $modelPath -Value $modelContent -Encoding utf8
}

Export-ModuleMember -Function Get-PbiTmdlIdentifier, Test-PbiMeasureExists, Test-PbiColumnExists, Test-PbiModuleRequirements, Test-PbiSemanticAssetsPresent, Install-PbiSemanticAssets
