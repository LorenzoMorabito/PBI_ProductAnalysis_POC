function Get-PbiTableDefinitionDirectoryForProject {
    param([Parameter(Mandatory = $true)]$Project)

    return (Join-Path $Project.SemanticModelPath "definition/tables")
}

function Get-PbiModelPathForProject {
    param([Parameter(Mandatory = $true)]$Project)

    return (Join-Path $Project.SemanticModelPath "definition/model.tmdl")
}

function Get-PbiPagesMetadataPathForProject {
    param([Parameter(Mandatory = $true)]$Project)

    return (Join-Path $Project.ReportPath "definition/pages/pages.json")
}

function Get-PbiPageDestinationRootForProject {
    param(
        [Parameter(Mandatory = $true)]$Project,
        [Parameter(Mandatory = $true)][string]$PageName
    )

    return (Join-Path $Project.ReportPath ("definition/pages/" + $PageName))
}

function Get-PbiMeasureNamesFromTmdlText {
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

function Get-PbiTmdlTableNameFromFile {
    param([Parameter(Mandatory = $true)][string]$Path)

    $content = Get-Content -Path $Path -Raw
    $match = [regex]::Match($content, "(?m)^\s*table\s+(?:'((?:[^']|'')+)'|([A-Za-z_][A-Za-z0-9_]*))(?=\s*$|\s)")

    if (-not $match.Success) {
        return $null
    }

    if ($match.Groups[1].Success) {
        return $match.Groups[1].Value.Replace("''", "'")
    }

    return $match.Groups[2].Value
}

function Get-PbiTmdlTableNamesFromDirectory {
    param([Parameter(Mandatory = $true)][string]$TableDirectory)

    $tableNames = New-Object System.Collections.Generic.List[string]

    foreach ($tableFile in (Get-ChildItem -Path $TableDirectory -Filter "*.tmdl" -ErrorAction SilentlyContinue)) {
        $tableName = Get-PbiTmdlTableNameFromFile -Path $tableFile.FullName
        if ($tableName) {
            $tableNames.Add($tableName)
        }
    }

    return @($tableNames | Select-Object -Unique)
}

function Get-PbiMeasureOccurrencesFromDirectory {
    param([Parameter(Mandatory = $true)][string]$TableDirectory)

    $occurrences = New-Object System.Collections.Generic.List[object]

    foreach ($tableFile in (Get-ChildItem -Path $TableDirectory -Filter "*.tmdl" -ErrorAction SilentlyContinue)) {
        $tableName = Get-PbiTmdlTableNameFromFile -Path $tableFile.FullName
        $content = Get-Content -Path $tableFile.FullName -Raw

        foreach ($measureName in (Get-PbiMeasureNamesFromTmdlText -Content $content)) {
            $occurrences.Add([PSCustomObject]@{
                Name      = $measureName
                TableName = $tableName
                Path      = $tableFile.FullName
            })
        }
    }

    return $occurrences.ToArray()
}

function Get-PbiFieldParameterTableNamesFromDirectory {
    param([Parameter(Mandatory = $true)][string]$TableDirectory)

    $tableNames = New-Object System.Collections.Generic.List[string]

    foreach ($tableFile in (Get-ChildItem -Path $TableDirectory -Filter "*.tmdl" -ErrorAction SilentlyContinue)) {
        $content = Get-Content -Path $tableFile.FullName -Raw

        if ($content -match "extendedProperty\s+ParameterMetadata") {
            $tableName = Get-PbiTmdlTableNameFromFile -Path $tableFile.FullName
            if ($tableName) {
                $tableNames.Add($tableName)
            }
        }
    }

    return @($tableNames | Select-Object -Unique)
}

function Get-PbiReportJsonFilesFromRoot {
    param([Parameter(Mandatory = $true)][string]$ReportRoot)

    if (-not (Test-Path $ReportRoot)) {
        return @()
    }

    return @(Get-ChildItem -Path $ReportRoot -Recurse -Filter "*.json" -File)
}

function Get-PbiVisualJsonFilesFromRoot {
    param([Parameter(Mandatory = $true)][string]$ReportRoot)

    if (-not (Test-Path $ReportRoot)) {
        return @()
    }

    return @(Get-ChildItem -Path $ReportRoot -Recurse -Filter "visual.json" -File)
}

function Get-PbiEntityNamesFromJsonText {
    param([Parameter(Mandatory = $true)][string]$Content)

    $matches = [regex]::Matches($Content, '"Entity"\s*:\s*"([^"]+)"')
    $entities = New-Object System.Collections.Generic.List[string]

    foreach ($match in $matches) {
        $entities.Add($match.Groups[1].Value)
    }

    return @($entities | Select-Object -Unique)
}

function Get-PbiManifestReferencedCoreTableNames {
    param([Parameter(Mandatory = $true)]$Manifest)

    $tableNames = New-Object System.Collections.Generic.List[string]

    foreach ($columnReference in @($Manifest.requires.coreColumns)) {
        if ($columnReference -match "^(?<Table>.+?)\[(?<Column>.+)\]$") {
            $tableNames.Add($Matches.Table)
        }
    }

    return @($tableNames | Select-Object -Unique)
}

function Get-PbiPbipFilesFromWorkspace {
    param([Parameter(Mandatory = $true)][string]$WorkspaceRoot)

    return @(Get-ChildItem -Path $WorkspaceRoot -Filter "*.pbip" -File)
}

Export-ModuleMember -Function Get-PbiTableDefinitionDirectoryForProject, Get-PbiModelPathForProject, Get-PbiPagesMetadataPathForProject, Get-PbiPageDestinationRootForProject, Get-PbiMeasureNamesFromTmdlText, Get-PbiTmdlTableNameFromFile, Get-PbiTmdlTableNamesFromDirectory, Get-PbiMeasureOccurrencesFromDirectory, Get-PbiFieldParameterTableNamesFromDirectory, Get-PbiReportJsonFilesFromRoot, Get-PbiVisualJsonFilesFromRoot, Get-PbiEntityNamesFromJsonText, Get-PbiManifestReferencedCoreTableNames, Get-PbiPbipFilesFromWorkspace
