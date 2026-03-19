function New-PbiResolvedMappings {
    return [ordered]@{
        coreMeasures = [ordered]@{}
        coreColumns  = [ordered]@{}
    }
}

function ConvertTo-PbiResolvedMappings {
    param($Mappings)

    $resolved = New-PbiResolvedMappings
    if ($null -eq $Mappings) {
        return $resolved
    }

    foreach ($sectionName in @("coreMeasures", "coreColumns")) {
        $section = $Mappings.$sectionName
        if ($null -eq $section) {
            continue
        }

        if ($section -is [System.Collections.IDictionary]) {
            foreach ($key in $section.Keys) {
                $resolved[$sectionName][[string]$key] = [string]$section[$key]
            }
        }
        else {
            foreach ($property in $section.PSObject.Properties) {
                $resolved[$sectionName][$property.Name] = [string]$property.Value
            }
        }
    }

    return $resolved
}

function Get-PbiResolvedMappingSection {
    param(
        [Parameter(Mandatory = $true)]$ResolvedMappings,
        [Parameter(Mandatory = $true)][string]$SectionName
    )

    if ($ResolvedMappings -is [System.Collections.IDictionary]) {
        if ($ResolvedMappings.Contains($SectionName)) {
            return $ResolvedMappings[$SectionName]
        }

        return $null
    }

    return $ResolvedMappings.$SectionName
}

function ConvertTo-PbiBindingRoleId {
    param(
        [Parameter(Mandatory = $true)][string]$Prefix,
        [Parameter(Mandatory = $true)][string]$Text,
        [int]$Ordinal = 0
    )

    $normalized = $Text.ToLowerInvariant() -replace "[^a-z0-9]+", "_"
    $normalized = $normalized.Trim("_")
    if ([string]::IsNullOrWhiteSpace($normalized)) {
        $normalized = ("role_{0}" -f $Ordinal)
    }

    return ($Prefix + "_" + $normalized)
}

function ConvertFrom-PbiColumnReference {
    param([Parameter(Mandatory = $true)][string]$ColumnReference)

    if ($ColumnReference -notmatch "^(?<Table>.+?)\[(?<Column>.+)\]$") {
        throw "Column reference '$ColumnReference' is not in the expected Table[Column] format."
    }

    return [PSCustomObject]@{
        TableName      = $Matches.Table
        ColumnName     = $Matches.Column
        Reference      = $ColumnReference
        QueryReference = ($Matches.Table + "." + $Matches.Column)
    }
}

function Get-PbiBindingContractRoleStringHints {
    param([Parameter(Mandatory = $true)]$Role)

    $hints = New-Object System.Collections.Generic.List[string]
    foreach ($value in @($Role.bindingKey, $Role.label, $Role.description, $Role.semanticRole)) {
        if (-not [string]::IsNullOrWhiteSpace([string]$value)) {
            $hints.Add([string]$value)
        }
    }

    foreach ($suggestion in @($Role.suggestions)) {
        if (-not [string]::IsNullOrWhiteSpace([string]$suggestion)) {
            $hints.Add([string]$suggestion)
        }
    }

    return @($hints | Select-Object -Unique)
}

function Get-PbiDerivedBindingContract {
    param([Parameter(Mandatory = $true)]$Manifest)

    $roles = @()
    $ordinal = 0

    foreach ($measureName in @($Manifest.requires.coreMeasures)) {
        $ordinal += 1
        $roles += (New-PbiNormalizedBindingRole -Role @{
                id           = ConvertTo-PbiBindingRoleId -Prefix "measure" -Text $measureName -Ordinal $ordinal
                bindingKey   = $measureName
                kind         = "measure"
                required     = $true
                label        = $measureName
                description  = ("Map module measure requirement '{0}'." -f $measureName)
                semanticRole = ""
                suggestions  = @()
                defaultValue = $measureName
            } -Ordinal $ordinal)
    }

    foreach ($columnReference in @($Manifest.requires.coreColumns)) {
        $ordinal += 1
        $roles += (New-PbiNormalizedBindingRole -Role @{
                id           = ConvertTo-PbiBindingRoleId -Prefix "column" -Text $columnReference -Ordinal $ordinal
                bindingKey   = $columnReference
                kind         = "column"
                required     = $true
                label        = $columnReference
                description  = ("Map module column requirement '{0}'." -f $columnReference)
                semanticRole = ""
                suggestions  = @()
                defaultValue = $columnReference
            } -Ordinal $ordinal)
    }

    return [ordered]@{
        mode        = "derived"
        roles       = @($roles)
        collections = @()
    }
}

function New-PbiNormalizedBindingRole {
    param(
        [Parameter(Mandatory = $true)]$Role,
        [int]$Ordinal = 0
    )

    $bindingKey = if ($Role.bindingKey) { [string]$Role.bindingKey } else { "" }
    $kind = if ($Role.kind) { [string]$Role.kind } else { "" }

    return [PSCustomObject]@{
        id                           = if ($Role.id) { [string]$Role.id } else { ConvertTo-PbiBindingRoleId -Prefix $kind -Text $bindingKey -Ordinal $Ordinal }
        bindingKey                   = $bindingKey
        kind                         = $kind
        required                     = if ($null -ne $Role.required) { [bool]$Role.required } else { $true }
        label                        = if ($Role.label) { [string]$Role.label } else { $bindingKey }
        description                  = if ($Role.description) { [string]$Role.description } else { ("Map '{0}'." -f $bindingKey) }
        semanticRole                 = if ($Role.semanticRole) { [string]$Role.semanticRole } else { "" }
        suggestions                  = @($Role.suggestions)
        defaultValue                 = if ($null -ne $Role.defaultValue) { [string]$Role.defaultValue } else { $bindingKey }
        collectionId                 = if ($Role.collectionId) { [string]$Role.collectionId } else { "" }
        collectionLabel              = if ($Role.collectionLabel) { [string]$Role.collectionLabel } else { "" }
        collectionItemLabel          = if ($Role.collectionItemLabel) { [string]$Role.collectionItemLabel } else { "" }
        collectionDescription        = if ($Role.collectionDescription) { [string]$Role.collectionDescription } else { "" }
        collectionKind               = if ($Role.collectionKind) { [string]$Role.collectionKind } else { "" }
        collectionMinItems           = if ($null -ne $Role.collectionMinItems) { [int]$Role.collectionMinItems } else { 0 }
        collectionMaxItems           = if ($null -ne $Role.collectionMaxItems) { [int]$Role.collectionMaxItems } else { 0 }
        collectionDefaultVisibleCount = if ($null -ne $Role.collectionDefaultVisibleCount) { [int]$Role.collectionDefaultVisibleCount } else { 0 }
        collectionOrdinal            = if ($null -ne $Role.collectionOrdinal) { [int]$Role.collectionOrdinal } else { 0 }
    }
}

function Get-PbiBindingContractCollectionDefaultItem {
    param(
        [Parameter(Mandatory = $true)]$Collection,
        [Parameter(Mandatory = $true)][int]$Ordinal
    )

    $defaultItems = @($Collection.defaultItems)
    if ($Ordinal -le $defaultItems.Count) {
        return $defaultItems[$Ordinal - 1]
    }

    return $null
}

function Get-PbiNormalizedBindingCollections {
    param([Parameter(Mandatory = $true)]$Collections)

    $normalizedCollections = @()
    $normalizedRoles = @()
    $ordinal = 0

    foreach ($collection in @($Collections)) {
        $collectionId = [string]$collection.id
        $collectionKind = [string]$collection.kind
        $minItems = if ($null -ne $collection.minItems) { [int]$collection.minItems } else { 1 }
        $maxItems = if ($null -ne $collection.maxItems) { [int]$collection.maxItems } else { $minItems }
        $defaultVisibleCount = if ($null -ne $collection.defaultVisibleCount) { [int]$collection.defaultVisibleCount } else { $minItems }

        $normalizedCollections += [PSCustomObject]@{
            id                  = $collectionId
            kind                = $collectionKind
            label               = [string]$collection.label
            description         = [string]$collection.description
            itemLabel           = if ($collection.itemLabel) { [string]$collection.itemLabel } else { [string]$collection.label }
            minItems            = $minItems
            maxItems            = $maxItems
            defaultVisibleCount = $defaultVisibleCount
            bindingKeyPrefix    = [string]$collection.bindingKeyPrefix
            bindingKeySuffix    = if ($collection.bindingKeySuffix) { [string]$collection.bindingKeySuffix } else { "" }
            defaultItems        = @($collection.defaultItems)
        }

        for ($collectionOrdinal = 1; $collectionOrdinal -le $maxItems; $collectionOrdinal++) {
            $ordinal += 1
            $defaultItem = Get-PbiBindingContractCollectionDefaultItem -Collection $collection -Ordinal $collectionOrdinal
            $bindingKeySuffix = if ($collection.bindingKeySuffix) { [string]$collection.bindingKeySuffix } else { "" }
            $bindingKey = ("{0}{1}{2}" -f [string]$collection.bindingKeyPrefix, $collectionOrdinal, $bindingKeySuffix)
            $itemLabel = if ($defaultItem -and $defaultItem.label) {
                [string]$defaultItem.label
            }
            elseif ($collection.itemLabel) {
                ("{0} {1}" -f [string]$collection.itemLabel, $collectionOrdinal)
            }
            else {
                ("{0} {1}" -f [string]$collection.label, $collectionOrdinal)
            }
            $itemDescription = if ($defaultItem -and $defaultItem.description) {
                [string]$defaultItem.description
            }
            else {
                [string]$collection.description
            }
            $itemDefaultValue = if (($collectionOrdinal -le $defaultVisibleCount) -and $defaultItem -and $defaultItem.defaultValue) {
                [string]$defaultItem.defaultValue
            }
            else {
                ""
            }

            $normalizedRole = New-PbiNormalizedBindingRole -Role @{
                id                            = ("{0}_{1}" -f $collectionId, $collectionOrdinal)
                bindingKey                    = $bindingKey
                kind                          = $collectionKind
                required                      = ($collectionOrdinal -le $minItems)
                label                         = $itemLabel
                description                   = $itemDescription
                semanticRole                  = ("{0}.{1}" -f $collectionId, $collectionOrdinal)
                suggestions                   = if ($defaultItem -and $defaultItem.suggestions) { @($defaultItem.suggestions) } else { @() }
                defaultValue                  = $itemDefaultValue
                collectionId                  = $collectionId
                collectionLabel               = [string]$collection.label
                collectionItemLabel           = if ($collection.itemLabel) { [string]$collection.itemLabel } else { [string]$collection.label }
                collectionDescription         = [string]$collection.description
                collectionKind                = $collectionKind
                collectionMinItems            = $minItems
                collectionMaxItems            = $maxItems
                collectionDefaultVisibleCount = $defaultVisibleCount
                collectionOrdinal             = $collectionOrdinal
            } -Ordinal $ordinal
            $normalizedRoles += $normalizedRole
        }
    }

    return [PSCustomObject]@{
        Collections = @($normalizedCollections)
        Roles       = @($normalizedRoles)
    }
}

function Get-PbiModuleBindingContract {
    param([Parameter(Mandatory = $true)]$Manifest)

    if (-not $Manifest.bindingContract) {
        return (Get-PbiDerivedBindingContract -Manifest $Manifest)
    }

    $bindingContract = $Manifest.bindingContract
    $bindingRoles = if ($bindingContract.PSObject.Properties['roles']) { @($bindingContract.roles) } else { @() }
    $bindingCollections = if ($bindingContract.PSObject.Properties['collections']) { @($bindingContract.collections) } else { @() }
    $normalizedRoles = @()
    $normalizedCollections = @()
    $ordinal = 0
    foreach ($role in $bindingRoles) {
        $ordinal += 1
        $normalizedRoles += (New-PbiNormalizedBindingRole -Role $role -Ordinal $ordinal)
    }

    if ($bindingCollections.Count -gt 0) {
        $collectionContract = Get-PbiNormalizedBindingCollections -Collections $bindingCollections
        $normalizedCollections = @($collectionContract.Collections)
        $normalizedRoles += @($collectionContract.Roles)
    }

    return [ordered]@{
        mode        = if ($bindingContract.mode) { [string]$bindingContract.mode } else { "guided" }
        roles       = @($normalizedRoles)
        collections = @($normalizedCollections)
    }
}

function Get-PbiBindingContractDefaultMappings {
    param([Parameter(Mandatory = $true)]$Manifest)

    $contract = Get-PbiModuleBindingContract -Manifest $Manifest
    $defaults = New-PbiResolvedMappings

    foreach ($role in @($contract.roles)) {
        if ([string]::IsNullOrWhiteSpace([string]$role.defaultValue)) {
            continue
        }

        $sectionName = if ($role.kind -eq "measure") { "coreMeasures" } else { "coreColumns" }
        $defaults[$sectionName][[string]$role.bindingKey] = [string]$role.defaultValue
    }

    return $defaults
}

function Get-PbiProjectBindingProfiles {
    param(
        [Parameter(Mandatory = $true)]$Project,
        [string]$ModuleId
    )

    if (-not (Test-Path $Project.MappingProfilesRoot)) {
        return @()
    }

    $searchRoot = if ($ModuleId) {
        Join-Path $Project.MappingProfilesRoot $ModuleId
    }
    else {
        $Project.MappingProfilesRoot
    }

    if (-not (Test-Path $searchRoot)) {
        return @()
    }

    $profiles = New-Object System.Collections.Generic.List[object]
    foreach ($profilePath in (Get-ChildItem -Path $searchRoot -Recurse -File -Filter "*.json" -ErrorAction SilentlyContinue)) {
        $profile = Read-PbiJsonFile -Path $profilePath.FullName
        if ($profile.savedAt -is [datetime]) {
            $profile.savedAt = $profile.savedAt.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        }
        Test-PbiBindingProfileSchema -Profile $profile -ProfilePath $profilePath.FullName
        $profiles.Add([PSCustomObject]@{
            ProfileId    = $profile.profileId
            ModuleId     = $profile.moduleId
            Domain       = if ($profile.domain) { [string]$profile.domain } else { "" }
            BindingMode  = if ($profile.bindingMode) { [string]$profile.bindingMode } else { "" }
            SavedAt      = $profile.savedAt
            ProfilePath  = $profilePath.FullName
            RelativePath = Get-PbiRelativePath -BasePath $Project.ProjectRoot -Path $profilePath.FullName
            Profile      = $profile
        })
    }

    return @($profiles | Sort-Object ModuleId, ProfileId)
}

function Get-PbiBindingProfile {
    param(
        [Parameter(Mandatory = $true)]$Project,
        [Parameter(Mandatory = $true)][string]$ModuleId,
        [Parameter(Mandatory = $true)][string]$ProfileId
    )

    $profilePath = Join-Path (Join-Path $Project.MappingProfilesRoot $ModuleId) ($ProfileId + ".json")
    if (-not (Test-Path $profilePath)) {
        throw "Binding profile '$ProfileId' for module '$ModuleId' was not found in project '$($Project.ProjectId)'."
    }

    $profile = Read-PbiJsonFile -Path $profilePath
    if ($profile.savedAt -is [datetime]) {
        $profile.savedAt = $profile.savedAt.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    }
    Test-PbiBindingProfileSchema -Profile $profile -ProfilePath $profilePath
    return [PSCustomObject]@{
        ProfilePath  = $profilePath
        RelativePath = Get-PbiRelativePath -BasePath $Project.ProjectRoot -Path $profilePath
        Profile      = $profile
        Hash         = Get-PbiJsonObjectHash -InputObject $profile
    }
}

function Save-PbiBindingProfile {
    param(
        [Parameter(Mandatory = $true)]$Project,
        [Parameter(Mandatory = $true)]$Module,
        [Parameter(Mandatory = $true)][string]$ProfileId,
        [Parameter(Mandatory = $true)]$ResolvedMappings,
        [string]$BindingMode = "guided",
        [string]$Description = ""
    )

    $moduleProfileDir = Join-Path $Project.MappingProfilesRoot $Module.ModuleId
    Ensure-PbiDirectory -Path $moduleProfileDir
    $profilePath = Join-Path $moduleProfileDir ($ProfileId + ".json")

    $profile = [ordered]@{
        schemaVersion    = "1.0.0"
        profileId        = $ProfileId
        moduleId         = $Module.ModuleId
        domain           = $Module.Domain
        moduleVersion    = $Module.Version
        bindingMode      = $BindingMode
        savedAt          = Get-PbiUtcTimestamp
        description      = $Description
        resolvedMappings = ConvertTo-PbiResolvedMappings -Mappings $ResolvedMappings
        bindingSelections = Get-PbiModuleBindingSelections -Manifest $Module.Manifest -ResolvedMappings $ResolvedMappings
    }

    Test-PbiBindingProfileSchema -Profile $profile -ProfilePath $profilePath
    Write-PbiJsonFile -Path $profilePath -InputObject $profile

    return [PSCustomObject]@{
        ProfilePath  = $profilePath
        RelativePath = Get-PbiRelativePath -BasePath $Project.ProjectRoot -Path $profilePath
        Profile      = $profile
        Hash         = Get-PbiJsonObjectHash -InputObject $profile
    }
}

function Get-PbiColumnNamesFromTmdlContent {
    param([Parameter(Mandatory = $true)][string]$Content)

    $pattern = "(?m)^\s*column\s+(?:'((?:[^']|'')+)'|([A-Za-z_][A-Za-z0-9_]*))(?=\s*$|\s)"
    $matches = [regex]::Matches($Content, $pattern)
    $columnNames = New-Object System.Collections.Generic.List[string]

    foreach ($match in $matches) {
        if ($match.Groups[1].Success) {
            $columnNames.Add($match.Groups[1].Value.Replace("''", "'"))
        }
        elseif ($match.Groups[2].Success) {
            $columnNames.Add($match.Groups[2].Value)
        }
    }

    return @($columnNames | Select-Object -Unique)
}

function Get-PbiMeasureNamesFromBindingTmdlContent {
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

function Get-PbiProjectMeasureCandidates {
    param([Parameter(Mandatory = $true)]$Project)

    $tableDirectory = Join-Path $Project.SemanticModelPath "definition/tables"
    if (-not (Test-Path $tableDirectory)) {
        return @()
    }

    $candidates = New-Object System.Collections.Generic.List[object]
    foreach ($tablePath in (Get-ChildItem -Path $tableDirectory -Filter "*.tmdl" -File -ErrorAction SilentlyContinue)) {
        $tableName = [System.IO.Path]::GetFileNameWithoutExtension($tablePath.Name)
        $content = Get-Content -Path $tablePath.FullName -Raw
        foreach ($measureName in @(Get-PbiMeasureNamesFromBindingTmdlContent -Content $content)) {
            $candidates.Add([PSCustomObject]@{
                ObjectType = "measure"
                TableName  = $tableName
                Name       = $measureName
                Value      = $measureName
                Label      = ("[{0}] ({1})" -f $measureName, $tableName)
            })
        }
    }

    return @($candidates | Sort-Object Name, TableName)
}

function Get-PbiProjectColumnCandidates {
    param([Parameter(Mandatory = $true)]$Project)

    $tableDirectory = Join-Path $Project.SemanticModelPath "definition/tables"
    if (-not (Test-Path $tableDirectory)) {
        return @()
    }

    $candidates = New-Object System.Collections.Generic.List[object]
    foreach ($tablePath in (Get-ChildItem -Path $tableDirectory -Filter "*.tmdl" -File -ErrorAction SilentlyContinue)) {
        $tableName = [System.IO.Path]::GetFileNameWithoutExtension($tablePath.Name)
        $content = Get-Content -Path $tablePath.FullName -Raw
        foreach ($columnName in @(Get-PbiColumnNamesFromTmdlContent -Content $content)) {
            $reference = ("{0}[{1}]" -f $tableName, $columnName)
            $candidates.Add([PSCustomObject]@{
                ObjectType  = "column"
                TableName   = $tableName
                ColumnName  = $columnName
                Value       = $reference
                Reference   = $reference
                QueryRef    = ($tableName + "." + $columnName)
                Label       = ("{0}[{1}]" -f $tableName, $columnName)
            })
        }
    }

    return @($candidates | Sort-Object TableName, ColumnName)
}

function ConvertTo-PbiNormalizedTokens {
    param([Parameter(Mandatory = $true)][string]$Text)

    $cleaned = $Text.ToLowerInvariant()
    $cleaned = $cleaned -replace "t_dim_", " "
    $cleaned = $cleaned -replace "t_fct_", " "
    $cleaned = $cleaned -replace "[\\[\\]\\(\\)\\.\\-_/]", " "
    $cleaned = $cleaned -replace "\s+", " "
    $parts = @($cleaned.Trim().Split(" ", [System.StringSplitOptions]::RemoveEmptyEntries))
    return @($parts | Select-Object -Unique)
}

function Get-PbiOverlapScore {
    param(
        [Parameter(Mandatory = $true)][string[]]$Left,
        [Parameter(Mandatory = $true)][string[]]$Right
    )

    if (($Left.Count -eq 0) -or ($Right.Count -eq 0)) {
        return 0
    }

    $shared = @($Left | Where-Object { $Right -contains $_ } | Select-Object -Unique)
    if ($shared.Count -eq 0) {
        return 0
    }

    return [int](100 * ($shared.Count / [double][Math]::Max($Left.Count, $Right.Count)))
}

function Get-PbiBindingCandidateScore {
    param(
        [Parameter(Mandatory = $true)]$Role,
        [Parameter(Mandatory = $true)]$Candidate
    )

    $expectedHints = @(Get-PbiBindingContractRoleStringHints -Role $Role)
    $candidateHints = New-Object System.Collections.Generic.List[string]

    if ($Role.kind -eq "measure") {
        $candidateHints.Add($Candidate.Name)
        $candidateHints.Add($Candidate.Label)
    }
    else {
        $candidateHints.Add($Candidate.Reference)
        $candidateHints.Add($Candidate.ColumnName)
        $candidateHints.Add($Candidate.TableName)
        $candidateHints.Add($Candidate.Label)
    }

    $bestScore = 0
    foreach ($expected in $expectedHints) {
        foreach ($candidateHint in @($candidateHints | Select-Object -Unique)) {
            if ([string]::Equals($expected, $candidateHint, [System.StringComparison]::OrdinalIgnoreCase)) {
                return 100
            }

            $expectedTokens = @(ConvertTo-PbiNormalizedTokens -Text $expected)
            $candidateTokens = @(ConvertTo-PbiNormalizedTokens -Text $candidateHint)
            $score = Get-PbiOverlapScore -Left $expectedTokens -Right $candidateTokens

            if (($score -lt 100) -and ($candidateHint.ToLowerInvariant().Contains($expected.ToLowerInvariant()) -or $expected.ToLowerInvariant().Contains($candidateHint.ToLowerInvariant()))) {
                $score = [Math]::Max($score, 80)
            }

            if ($score -gt $bestScore) {
                $bestScore = $score
            }
        }
    }

    return $bestScore
}

function Get-PbiRoleCurrentBindingValue {
    param(
        [Parameter(Mandatory = $true)]$Role,
        [Parameter(Mandatory = $true)]$ResolvedMappings
    )

    $sectionName = if ($Role.kind -eq "measure") { "coreMeasures" } else { "coreColumns" }
    $mappingSection = Get-PbiResolvedMappingSection -ResolvedMappings $ResolvedMappings -SectionName $sectionName
    if ($mappingSection -and $mappingSection.Contains($Role.bindingKey)) {
        return [string]$mappingSection[$Role.bindingKey]
    }

    return [string]$Role.bindingKey
}

function Get-PbiBindingCollectionActiveCounts {
    param(
        [Parameter(Mandatory = $true)]$Contract,
        [Parameter(Mandatory = $true)]$ResolvedMappings
    )

    $counts = @{}
    foreach ($collection in @($Contract.collections)) {
        $activeCount = 0
        $collectionRoles = @($Contract.roles | Where-Object { $_.collectionId -eq $collection.id } | Sort-Object collectionOrdinal)
        foreach ($role in $collectionRoles) {
            $sectionName = if ($role.kind -eq "measure") { "coreMeasures" } else { "coreColumns" }
            $mappingSection = Get-PbiResolvedMappingSection -ResolvedMappings $ResolvedMappings -SectionName $sectionName
            $selectedValue = if ($mappingSection -and $mappingSection.Contains($role.bindingKey)) {
                [string]$mappingSection[$role.bindingKey]
            }
            else {
                ""
            }

            if ([string]::IsNullOrWhiteSpace($selectedValue)) {
                break
            }

            $activeCount = [int]$role.collectionOrdinal
        }

        if ($activeCount -eq 0) {
            $activeCount = [Math]::Max([int]$collection.minItems, [int]$collection.defaultVisibleCount)
        }

        $counts[$collection.id] = [Math]::Min([int]$collection.maxItems, $activeCount)
    }

    return $counts
}

function Get-PbiModuleBindingSelections {
    param(
        [Parameter(Mandatory = $true)]$Manifest,
        [Parameter(Mandatory = $true)]$ResolvedMappings
    )

    $contract = Get-PbiModuleBindingContract -Manifest $Manifest
    $normalizedMappings = ConvertTo-PbiResolvedMappings -Mappings $ResolvedMappings
    $selectionData = [ordered]@{}

    foreach ($collection in @($contract.collections)) {
        $items = New-Object System.Collections.Generic.List[object]
        $collectionRoles = @($contract.roles | Where-Object { $_.collectionId -eq $collection.id } | Sort-Object collectionOrdinal)
        foreach ($role in $collectionRoles) {
            $sectionName = if ($role.kind -eq "measure") { "coreMeasures" } else { "coreColumns" }
            $mappingSection = Get-PbiResolvedMappingSection -ResolvedMappings $normalizedMappings -SectionName $sectionName
            if (-not ($mappingSection -and $mappingSection.Contains($role.bindingKey))) {
                continue
            }

            $selectedValue = [string]$mappingSection[$role.bindingKey]
            if ([string]::IsNullOrWhiteSpace($selectedValue)) {
                continue
            }

            $items.Add([ordered]@{
                    ordinal    = [int]$role.collectionOrdinal
                    bindingKey = [string]$role.bindingKey
                    label      = [string]$role.label
                    value      = $selectedValue
                    kind       = [string]$role.kind
                })
        }

        $selectionData[$collection.id] = @($items | Sort-Object ordinal)
    }

    return $selectionData
}

function Get-PbiModuleBindingSuggestions {
    param(
        [Parameter(Mandatory = $true)]$Project,
        [Parameter(Mandatory = $true)]$Module,
        $BaseMappings
    )

    $contract = Get-PbiModuleBindingContract -Manifest $Module.Manifest
    $resolvedBaseMappings = ConvertTo-PbiResolvedMappings -Mappings $BaseMappings
    $measureCandidates = @(Get-PbiProjectMeasureCandidates -Project $Project)
    $columnCandidates = @(Get-PbiProjectColumnCandidates -Project $Project)
    $roles = @()
    $activeCounts = Get-PbiBindingCollectionActiveCounts -Contract $contract -ResolvedMappings $resolvedBaseMappings

    foreach ($role in @($contract.roles)) {
        $isCollectionRole = -not [string]::IsNullOrWhiteSpace([string]$role.collectionId)
        $activeCollectionCount = if ($isCollectionRole -and $activeCounts.ContainsKey($role.collectionId)) { [int]$activeCounts[$role.collectionId] } else { 0 }
        $isActiveRole = (-not $isCollectionRole) -or ([int]$role.collectionOrdinal -le $activeCollectionCount)
        $sectionName = if ($role.kind -eq "measure") { "coreMeasures" } else { "coreColumns" }
        $mappingSection = Get-PbiResolvedMappingSection -ResolvedMappings $resolvedBaseMappings -SectionName $sectionName
        $candidates = if ($role.kind -eq "measure") { $measureCandidates } else { $columnCandidates }
        $rankedCandidates = @(
            foreach ($candidate in $candidates) {
                [PSCustomObject]@{
                    Value = if ($role.kind -eq "measure") { $candidate.Name } else { $candidate.Reference }
                    Label = $candidate.Label
                    Score = Get-PbiBindingCandidateScore -Role $role -Candidate $candidate
                }
            }
        ) | Sort-Object @{ Expression = "Score"; Descending = $true }, @{ Expression = "Label"; Descending = $false }

        $currentValue = Get-PbiRoleCurrentBindingValue -Role $role -ResolvedMappings $resolvedBaseMappings
        $topCandidates = @($rankedCandidates | Select-Object -First 10)
        $selectedValue = $currentValue
        $status = if ($isActiveRole) { "preset" } else { "optional-hidden" }
        $currentValueExists = [bool]($candidates | Where-Object {
                if ($role.kind -eq "measure") { $_.Name -eq $currentValue } else { $_.Reference -eq $currentValue }
            } | Select-Object -First 1)
        $isDefaultCurrentValue = (
            [string]::Equals($currentValue, [string]$role.bindingKey, [System.StringComparison]::OrdinalIgnoreCase) -or
            [string]::Equals($currentValue, [string]$role.defaultValue, [System.StringComparison]::OrdinalIgnoreCase)
        )

        if ($isCollectionRole -and -not $isActiveRole -and (-not ($mappingSection -and $mappingSection.Contains($role.bindingKey)))) {
            $selectedValue = ""
            $status = "optional-hidden"
        }
        elseif ($isDefaultCurrentValue -and -not $currentValueExists) {
            if ($topCandidates.Count -eq 0) {
                $status = "missing"
            }
            elseif ($topCandidates[0].Score -ge 95) {
                $selectedValue = $topCandidates[0].Value
                $status = "exact"
            }
            elseif (($topCandidates[0].Score -ge 55) -and (($topCandidates.Count -eq 1) -or (($topCandidates[0].Score - $topCandidates[1].Score) -ge 15))) {
                $selectedValue = $topCandidates[0].Value
                $status = "suggested"
            }
            else {
                $status = "ambiguous"
            }
        }
        elseif ([string]::Equals($currentValue, $role.bindingKey, [System.StringComparison]::OrdinalIgnoreCase)) {
            if ($topCandidates.Count -eq 0) {
                $status = "missing"
            }
            elseif ($topCandidates[0].Score -ge 95) {
                $selectedValue = $topCandidates[0].Value
                $status = "exact"
            }
            elseif (($topCandidates[0].Score -ge 55) -and (($topCandidates.Count -eq 1) -or (($topCandidates[0].Score - $topCandidates[1].Score) -ge 15))) {
                $selectedValue = $topCandidates[0].Value
                $status = "suggested"
            }
            else {
                $status = "ambiguous"
            }
        }
        elseif (-not $currentValueExists) {
            $status = "custom"
        }

        $roles += [PSCustomObject]@{
            Id               = $role.id
            Kind             = $role.kind
            BindingKey       = $role.bindingKey
            Label            = $role.label
            Description      = $role.description
            Required         = [bool]$role.required
            SelectedValue    = if (($status -eq "optional-hidden") -and (-not ($mappingSection -and $mappingSection.Contains($role.bindingKey)))) { "" } else { $selectedValue }
            Status           = $status
            Candidates       = @($topCandidates)
            IsActive         = $isActiveRole
            CollectionId     = [string]$role.collectionId
            CollectionLabel  = [string]$role.collectionLabel
            CollectionKind   = [string]$role.collectionKind
            CollectionOrdinal = [int]$role.collectionOrdinal
        }
    }

    return [PSCustomObject]@{
        Contract         = $contract
        ResolvedMappings = $resolvedBaseMappings
        Roles            = @($roles)
        ActiveCounts     = $activeCounts
    }
}

function Resolve-PbiSuggestedMappings {
    param(
        [Parameter(Mandatory = $true)]$SuggestionSet
    )

    $resolvedMappings = ConvertTo-PbiResolvedMappings -Mappings $SuggestionSet.ResolvedMappings

    foreach ($role in @($SuggestionSet.Roles)) {
        if (($role.Required -or $role.IsActive) -and ($role.Status -in @("missing", "ambiguous"))) {
            throw "Unable to auto-resolve binding role '$($role.Label)'. Run the wizard with -Interactive or provide a profile."
        }

        if ([string]::IsNullOrWhiteSpace([string]$role.SelectedValue)) {
            continue
        }

        $sectionName = if ($role.Kind -eq "measure") { "coreMeasures" } else { "coreColumns" }
        $resolvedMappings[$sectionName][$role.BindingKey] = [string]$role.SelectedValue
    }

    return $resolvedMappings
}

function Invoke-PbiInteractiveBindingWizard {
    param(
        [Parameter(Mandatory = $true)]$SuggestionSet
    )

    $resolvedMappings = ConvertTo-PbiResolvedMappings -Mappings $SuggestionSet.ResolvedMappings

    foreach ($role in @($SuggestionSet.Roles)) {
        if (($role.CollectionId) -and (-not $role.IsActive) -and [string]::IsNullOrWhiteSpace([string]$role.SelectedValue)) {
            continue
        }

        Write-Host ""
        Write-Host ("Binding role: {0}" -f $role.Label)
        Write-Host ("  Kind: {0}" -f $role.Kind)
        Write-Host ("  Description: {0}" -f $role.Description)
        Write-Host ("  Status: {0}" -f $role.Status)

        $candidateIndex = 0
        foreach ($candidate in @($role.Candidates)) {
            $candidateIndex += 1
            $defaultMarker = if ($candidate.Value -eq $role.SelectedValue) { "*" } else { " " }
            Write-Host ("  {0} {1}. {2} [{3}]" -f $defaultMarker, $candidateIndex, $candidate.Label, $candidate.Score)
        }

        $defaultText = if (-not [string]::IsNullOrWhiteSpace([string]$role.SelectedValue)) { $role.SelectedValue } else { "" }

        while ($true) {
            $prompt = if ($defaultText) {
                "Select candidate number or type explicit value (Enter = " + $defaultText + ")"
            }
            else {
                "Select candidate number or type explicit value"
            }

            $response = Read-Host $prompt
            if ([string]::IsNullOrWhiteSpace($response)) {
                if ($defaultText) {
                    $selectedValue = $defaultText
                    break
                }

                if (-not $role.Required) {
                    $selectedValue = ""
                    break
                }

                Write-Host "  A value is required for this role."
                continue
            }

            $parsedIndex = 0
            if ([int]::TryParse($response, [ref]$parsedIndex)) {
                if (($parsedIndex -ge 1) -and ($parsedIndex -le $role.Candidates.Count)) {
                    $selectedValue = $role.Candidates[$parsedIndex - 1].Value
                    break
                }

                Write-Host "  Candidate index out of range."
                continue
            }

            $selectedValue = $response.Trim()
            break
        }

        $sectionName = if ($role.Kind -eq "measure") { "coreMeasures" } else { "coreColumns" }
        $resolvedMappings[$sectionName][$role.BindingKey] = $selectedValue
    }

    return $resolvedMappings
}

function Invoke-PbiInteractiveBindingUiWizard {
    param(
        [Parameter(Mandatory = $true)]$SuggestionSet,
        [Parameter(Mandatory = $true)]$Project,
        [Parameter(Mandatory = $true)]$Module,
        [string]$DefaultProfileId = ""
    )

    try {
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
    }
    catch {
        throw "Interactive UI wizard is not available on this host. Run without -InteractiveUi or use -Interactive."
    }

    $resolvedMappings = ConvertTo-PbiResolvedMappings -Mappings $SuggestionSet.ResolvedMappings
    $wizardState = [ordered]@{
        Ready              = $false
        Dirty              = $false
        LastTestPerformed  = $false
        LastTestPassed     = $false
        SavedProfileId     = ""
        SavedProfileHash   = ""
        AppliedResult      = $null
    }

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "PBI Modularity Binding Wizard"
    $form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $form.Size = [System.Drawing.Size]::new(1120, 880)
    $form.MinimumSize = [System.Drawing.Size]::new(980, 760)
    $form.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::Font

    $headerPanel = New-Object System.Windows.Forms.Panel
    $headerPanel.Dock = [System.Windows.Forms.DockStyle]::Top
    $headerPanel.Height = 92

    $headerTitle = New-Object System.Windows.Forms.Label
    $headerTitle.Text = "Resolve module bindings"
    $headerTitle.Font = [System.Drawing.Font]::new("Segoe UI", 13, [System.Drawing.FontStyle]::Bold)
    $headerTitle.AutoSize = $true
    $headerTitle.Location = [System.Drawing.Point]::new(16, 12)

    $headerBody = New-Object System.Windows.Forms.Label
    $headerBody.Text = "Review the suggested bindings, add only the dimensions and measures you want to expose, then use Save Profile, Test Bindings, and Apply. Each field accepts a candidate from the dropdown or an explicit value typed manually."
    $headerBody.AutoSize = $false
    $headerBody.Size = [System.Drawing.Size]::new(1040, 48)
    $headerBody.Location = [System.Drawing.Point]::new(16, 36)

    $headerPanel.Controls.Add($headerTitle)
    $headerPanel.Controls.Add($headerBody)

    $scrollPanel = New-Object System.Windows.Forms.FlowLayoutPanel
    $scrollPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $scrollPanel.FlowDirection = [System.Windows.Forms.FlowDirection]::TopDown
    $scrollPanel.WrapContents = $false
    $scrollPanel.AutoScroll = $true
    $scrollPanel.Padding = [System.Windows.Forms.Padding]::new(12, 4, 12, 4)

    $footerPanel = New-Object System.Windows.Forms.Panel
    $footerPanel.Dock = [System.Windows.Forms.DockStyle]::Bottom
    $footerPanel.Height = 164

    $profileLabel = New-Object System.Windows.Forms.Label
    $profileLabel.Text = "Profile Id"
    $profileLabel.AutoSize = $true
    $profileLabel.Location = [System.Drawing.Point]::new(16, 16)

    $profileTextBox = New-Object System.Windows.Forms.TextBox
    $profileTextBox.Size = [System.Drawing.Size]::new(260, 27)
    $profileTextBox.Location = [System.Drawing.Point]::new(84, 12)
    if (-not [string]::IsNullOrWhiteSpace($DefaultProfileId)) {
        $profileTextBox.Text = $DefaultProfileId
    }

    $footerHelp = New-Object System.Windows.Forms.Label
    $footerHelp.Text = "Visible rows are applied. Save stores the current mapping profile, Test validates current bindings, Apply uses the last passing tested state."
    $footerHelp.AutoSize = $false
    $footerHelp.Size = [System.Drawing.Size]::new(560, 32)
    $footerHelp.Location = [System.Drawing.Point]::new(16, 48)

    $statusSummaryLabel = New-Object System.Windows.Forms.Label
    $statusSummaryLabel.Text = "Not tested"
    $statusSummaryLabel.AutoSize = $true
    $statusSummaryLabel.Font = [System.Drawing.Font]::new("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)
    $statusSummaryLabel.Location = [System.Drawing.Point]::new(16, 88)

    $statusDetailsBox = New-Object System.Windows.Forms.TextBox
    $statusDetailsBox.Multiline = $true
    $statusDetailsBox.ReadOnly = $true
    $statusDetailsBox.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
    $statusDetailsBox.Size = [System.Drawing.Size]::new(700, 56)
    $statusDetailsBox.Location = [System.Drawing.Point]::new(16, 106)
    $statusDetailsBox.Text = "Run Test Bindings to validate the selected fields before applying them."

    $saveButton = New-Object System.Windows.Forms.Button
    $saveButton.Text = "Save Profile"
    $saveButton.Size = [System.Drawing.Size]::new(110, 32)
    $saveButton.Location = [System.Drawing.Point]::new(736, 14)

    $testButton = New-Object System.Windows.Forms.Button
    $testButton.Text = "Test Bindings"
    $testButton.Size = [System.Drawing.Size]::new(118, 32)
    $testButton.Location = [System.Drawing.Point]::new(852, 14)

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Text = "Cancel"
    $cancelButton.Size = [System.Drawing.Size]::new(96, 32)
    $cancelButton.Location = [System.Drawing.Point]::new(976, 14)
    $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel

    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Text = "Apply"
    $okButton.Size = [System.Drawing.Size]::new(144, 32)
    $okButton.Location = [System.Drawing.Point]::new(928, 54)

    $footerPanel.Controls.Add($profileLabel)
    $footerPanel.Controls.Add($profileTextBox)
    $footerPanel.Controls.Add($footerHelp)
    $footerPanel.Controls.Add($statusSummaryLabel)
    $footerPanel.Controls.Add($statusDetailsBox)
    $footerPanel.Controls.Add($saveButton)
    $footerPanel.Controls.Add($testButton)
    $footerPanel.Controls.Add($cancelButton)
    $footerPanel.Controls.Add($okButton)

    $bindingControls = @()

    $newComboBox = {
        param($Role)

        $comboBox = New-Object System.Windows.Forms.ComboBox
        $comboBox.Size = [System.Drawing.Size]::new(710, 26)
        $comboBox.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDown
        $comboBox.AutoCompleteMode = [System.Windows.Forms.AutoCompleteMode]::SuggestAppend
        $comboBox.AutoCompleteSource = [System.Windows.Forms.AutoCompleteSource]::ListItems

        $valuesAdded = New-Object System.Collections.Generic.HashSet[string]
        foreach ($candidate in $Role.Candidates) {
            $candidateValue = [string]$candidate.Value
            if (-not [string]::IsNullOrWhiteSpace($candidateValue) -and $valuesAdded.Add($candidateValue)) {
                [void]$comboBox.Items.Add($candidateValue)
            }
        }

        if (-not [string]::IsNullOrWhiteSpace([string]$Role.SelectedValue)) {
            $comboBox.Text = [string]$Role.SelectedValue
        }

        return $comboBox
    }

    $setStatus = {
        param(
            [string]$Summary,
            [string[]]$Details,
            [string]$Level = "info"
        )

        $statusSummaryLabel.Text = $Summary
        $statusDetailsBox.Text = (($Details | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join [Environment]::NewLine)

        switch ($Level) {
            "pass" {
                $statusSummaryLabel.ForeColor = [System.Drawing.Color]::ForestGreen
                $statusDetailsBox.ForeColor = [System.Drawing.Color]::ForestGreen
            }
            "fail" {
                $statusSummaryLabel.ForeColor = [System.Drawing.Color]::Firebrick
                $statusDetailsBox.ForeColor = [System.Drawing.Color]::Firebrick
            }
            "warn" {
                $statusSummaryLabel.ForeColor = [System.Drawing.Color]::DarkOrange
                $statusDetailsBox.ForeColor = [System.Drawing.Color]::DarkOrange
            }
            default {
                $statusSummaryLabel.ForeColor = [System.Drawing.Color]::Black
                $statusDetailsBox.ForeColor = [System.Drawing.Color]::Black
            }
        }
    }

    $markDirty = {
        if (-not $wizardState.Ready) {
            return
        }

        $wizardState.Dirty = $true
        if ($wizardState.LastTestPerformed) {
            & $setStatus "Modified after test" @("Bindings changed after the last test. Run Test Bindings again before Apply.") "warn"
        }
        elseif (-not [string]::IsNullOrWhiteSpace($wizardState.SavedProfileId)) {
            & $setStatus "Modified after save" @(("Profile '{0}' no longer matches the current selection." -f $wizardState.SavedProfileId)) "warn"
        }
        else {
            & $setStatus "Bindings edited" @("Save Profile to persist the current selection or run Test Bindings to validate it.") "info"
        }
    }

    $getSectionName = {
        param($Role)
        if ($Role.Kind -eq "measure") {
            return "coreMeasures"
        }

        return "coreColumns"
    }

    $collectCurrentMappings = {
        $nextResolvedMappings = New-PbiResolvedMappings

        foreach ($bindingControl in $bindingControls) {
            $role = $bindingControl.Role
            $sectionName = & $getSectionName $role
            $section = Get-PbiResolvedMappingSection -ResolvedMappings $nextResolvedMappings -SectionName $sectionName
            $isVisibleRow = $true
            if ($null -ne $bindingControl.RowPanel) {
                $isVisibleRow = [bool]$bindingControl.RowPanel.Visible
            }

            if (-not $isVisibleRow) {
                continue
            }

            $selectedValue = [string]$bindingControl.ComboBox.Text
            if ([string]::IsNullOrWhiteSpace($selectedValue)) {
                continue
            }

            $section[$role.BindingKey] = $selectedValue.Trim()
        }

        return $nextResolvedMappings
    }

    $validateRequiredInputs = {
        foreach ($bindingControl in $bindingControls) {
            if (-not $bindingControl.RowPanel.Visible) {
                continue
            }

            $role = $bindingControl.Role
            $selectedValue = [string]$bindingControl.ComboBox.Text
            $requiresValue = $false
            if ($null -ne $role.Required) {
                $requiresValue = [bool]$role.Required
            }
            if ((-not $requiresValue) -and ($null -ne $role.IsActive)) {
                $requiresValue = [bool]$role.IsActive
            }

            if ($requiresValue -and [string]::IsNullOrWhiteSpace($selectedValue)) {
                [System.Windows.Forms.MessageBox]::Show(
                    ("Binding '{0}' is required." -f $role.Label),
                    "Missing binding",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Warning
                ) | Out-Null
                $bindingControl.ComboBox.Focus()
                return $false
            }
        }

        return $true
    }

    $runBindingTest = {
        if (-not (& $validateRequiredInputs)) {
            return $false
        }

        $currentMappings = & $collectCurrentMappings
        $validation = Test-PbiModuleRequirements -Project $Project -Manifest $Module.Manifest -ResolvedMappings $currentMappings
        $measureConflicts = Test-PbiModuleMeasureConflicts -Project $Project -Module $Module -Manifest $Module.Manifest -ResolvedMappings $currentMappings
        $details = @()

        if ($validation.MissingMeasures.Count -gt 0) {
            $details += ("Missing measures: {0}" -f (($validation.MissingMeasures | Sort-Object) -join ", "))
        }

        if ($validation.MissingColumns.Count -gt 0) {
            $details += ("Missing columns: {0}" -f (($validation.MissingColumns | Sort-Object) -join ", "))
        }

        if ($measureConflicts.HasConflicts) {
            $details += ("Measure conflicts: {0}" -f (($measureConflicts.Conflicts | Sort-Object) -join ", "))
        }

        $isValid = ($validation.IsValid -and -not $measureConflicts.HasConflicts)
        if ($details.Count -eq 0) {
            $details += "Requirements and measure conflict checks passed."
        }

        $wizardState.LastTestPerformed = $true
        $wizardState.LastTestPassed = $isValid
        $wizardState.Dirty = $false

        if ($isValid) {
            & $setStatus "PASS" $details "pass"
        }
        else {
            & $setStatus "FAIL" $details "fail"
        }

        return $isValid
    }

    $saveCurrentProfile = {
        $profileId = [string]$profileTextBox.Text
        $profileId = $profileId.Trim()
        if ([string]::IsNullOrWhiteSpace($profileId)) {
            [System.Windows.Forms.MessageBox]::Show(
                "Enter a profile id before saving.",
                "Missing profile id",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            ) | Out-Null
            $profileTextBox.Focus()
            return $null
        }

        $currentMappings = & $collectCurrentMappings
        $savedProfile = Save-PbiBindingProfile -Project $Project -Module $Module -ProfileId $profileId -ResolvedMappings $currentMappings -BindingMode "interactive-ui"
        $wizardState.SavedProfileId = $savedProfile.Profile.profileId
        $wizardState.SavedProfileHash = $savedProfile.Hash
        $wizardState.Dirty = $false

        & $setStatus "Profile saved" @(
            ("Profile: {0}" -f $savedProfile.Profile.profileId),
            ("Path: {0}" -f $savedProfile.RelativePath)
        ) "info"

        return $savedProfile
    }

    $refreshCollectionSection = {
        param($Section)

        for ($index = 0; $index -lt $Section.RoleRows.Count; $index++) {
            $row = $Section.RoleRows[$index]
            $row.RowPanel.Visible = ($index -lt $Section.ActiveCount)
        }

        $visibleHeight = 74 + ($Section.ActiveCount * 38)
        $Section.GroupBox.Height = [Math]::Max($visibleHeight, 118)
        $Section.AddButton.Enabled = ($Section.ActiveCount -lt $Section.MaxItems)
        $Section.RemoveButton.Enabled = ($Section.ActiveCount -gt $Section.MinItems)
        $scrollPanel.PerformLayout()
    }

    foreach ($collection in $SuggestionSet.Contract.collections) {
        $collectionRoles = $SuggestionSet.Roles | Where-Object { $_.CollectionId -eq $collection.id } | Sort-Object CollectionOrdinal
        if ($collectionRoles.Count -eq 0) {
            continue
        }

        $activeCount = if ($SuggestionSet.ActiveCounts.ContainsKey($collection.id)) { [int]$SuggestionSet.ActiveCounts[$collection.id] } else { [int]$collection.defaultVisibleCount }
        $groupBox = New-Object System.Windows.Forms.GroupBox
        $groupBox.Text = ("{0} [{1}]" -f $collection.label, $collection.kind)
        $groupBox.Width = 980
        $groupBox.Height = 140
        $groupBox.Padding = [System.Windows.Forms.Padding]::new(10, 6, 10, 8)

        $descriptionLabel = New-Object System.Windows.Forms.Label
        $descriptionLabel.Text = $collection.description
        $descriptionLabel.AutoSize = $false
        $descriptionLabel.Size = [System.Drawing.Size]::new(760, 30)
        $descriptionLabel.Location = [System.Drawing.Point]::new(12, 24)

        $addButton = New-Object System.Windows.Forms.Button
        $addButton.Text = ("Add {0}" -f $collection.itemLabel)
        $addButton.Size = [System.Drawing.Size]::new(92, 28)
        $addButton.Location = [System.Drawing.Point]::new(780, 22)

        $removeButton = New-Object System.Windows.Forms.Button
        $removeButton.Text = "Remove last"
        $removeButton.Size = [System.Drawing.Size]::new(110, 28)
        $removeButton.Location = [System.Drawing.Point]::new(876, 22)

        $groupBox.Controls.Add($descriptionLabel)
        $groupBox.Controls.Add($addButton)
        $groupBox.Controls.Add($removeButton)

        $roleRows = @()
        foreach ($role in $collectionRoles) {
            $rowPanel = New-Object System.Windows.Forms.Panel
            $rowPanel.Size = [System.Drawing.Size]::new(940, 34)
            $rowPanel.Location = [System.Drawing.Point]::new(16, (60 + (($role.CollectionOrdinal - 1) * 36)))

            $rowLabel = New-Object System.Windows.Forms.Label
            $rowLabel.Text = $role.Label
            $rowLabel.AutoSize = $false
            $rowLabel.Size = [System.Drawing.Size]::new(180, 24)
            $rowLabel.Location = [System.Drawing.Point]::new(0, 6)

            $comboBox = & $newComboBox $role
            $comboBox.Location = [System.Drawing.Point]::new(190, 2)
            $comboBox.Add_TextChanged(({
                    & $markDirty
                }).GetNewClosure())

            $statusLabel = New-Object System.Windows.Forms.Label
            $statusLabel.Text = $role.Status
            $statusLabel.AutoSize = $false
            $statusLabel.Size = [System.Drawing.Size]::new(120, 24)
            $statusLabel.Location = [System.Drawing.Point]::new(910, 6)

            $rowPanel.Controls.Add($rowLabel)
            $rowPanel.Controls.Add($comboBox)
            $rowPanel.Controls.Add($statusLabel)
            $groupBox.Controls.Add($rowPanel)

            $rowRecord = [PSCustomObject]@{
                Role      = $role
                ComboBox  = $comboBox
                RowPanel  = $rowPanel
                Status    = $statusLabel
            }
            $roleRows += $rowRecord
            $bindingControls += $rowRecord
        }

        $sectionRecord = [PSCustomObject]@{
            CollectionId  = $collection.id
            GroupBox      = $groupBox
            AddButton     = $addButton
            RemoveButton  = $removeButton
            RoleRows      = $roleRows
            ActiveCount   = [Math]::Min([int]$collection.maxItems, [Math]::Max([int]$collection.minItems, $activeCount))
            MinItems      = [int]$collection.minItems
            MaxItems      = [int]$collection.maxItems
        }

        $addButton.Add_Click(({
                if ($sectionRecord.ActiveCount -lt $sectionRecord.MaxItems) {
                    $sectionRecord.ActiveCount += 1
                    & $refreshCollectionSection $sectionRecord
                    & $markDirty
                }
            }).GetNewClosure())
        $removeButton.Add_Click(({
                if ($sectionRecord.ActiveCount -gt $sectionRecord.MinItems) {
                    $lastRow = $sectionRecord.RoleRows[$sectionRecord.ActiveCount - 1]
                    $lastRow.ComboBox.Text = ""
                    $sectionRecord.ActiveCount -= 1
                    & $refreshCollectionSection $sectionRecord
                    & $markDirty
                }
            }).GetNewClosure())

        & $refreshCollectionSection $sectionRecord
        [void]$scrollPanel.Controls.Add($groupBox)
    }

    foreach ($role in ($SuggestionSet.Roles | Where-Object { [string]::IsNullOrWhiteSpace($_.CollectionId) })) {
        $groupBox = New-Object System.Windows.Forms.GroupBox
        $groupBox.Text = ("{0} [{1}] - {2}" -f $role.Label, $role.Kind, $role.Status)
        $groupBox.Width = 980
        $groupBox.Height = 104
        $groupBox.Padding = [System.Windows.Forms.Padding]::new(10, 6, 10, 8)

        $descriptionLabel = New-Object System.Windows.Forms.Label
        $descriptionLabel.Text = $role.Description
        $descriptionLabel.AutoSize = $false
        $descriptionLabel.Size = [System.Drawing.Size]::new(930, 30)
        $descriptionLabel.Location = [System.Drawing.Point]::new(12, 24)

        $comboLabel = New-Object System.Windows.Forms.Label
        $comboLabel.Text = "Selected value"
        $comboLabel.AutoSize = $true
        $comboLabel.Location = [System.Drawing.Point]::new(12, 60)

        $comboBox = & $newComboBox $role
        $comboBox.Location = [System.Drawing.Point]::new(110, 56)
        $comboBox.Add_TextChanged(({
                & $markDirty
            }).GetNewClosure())

        $groupBox.Controls.Add($descriptionLabel)
        $groupBox.Controls.Add($comboLabel)
        $groupBox.Controls.Add($comboBox)
        [void]$scrollPanel.Controls.Add($groupBox)

        $bindingControls += [PSCustomObject]@{
            Role      = $role
            ComboBox  = $comboBox
            RowPanel  = $groupBox
        }
    }

    $form.Controls.Add($scrollPanel)
    $form.Controls.Add($footerPanel)
    $form.Controls.Add($headerPanel)
    $form.AcceptButton = $okButton
    $form.CancelButton = $cancelButton

    $saveButton.Add_Click(({
            $null = & $saveCurrentProfile
        }).GetNewClosure())

    $testButton.Add_Click(({
            $null = & $runBindingTest
        }).GetNewClosure())

    $okButton.Add_Click(({
            if (-not (& $validateRequiredInputs)) {
                return
            }

            if (-not $wizardState.LastTestPerformed) {
                [System.Windows.Forms.MessageBox]::Show(
                    "Run Test Bindings before Apply.",
                    "Bindings not tested",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Warning
                ) | Out-Null
                return
            }

            if ($wizardState.Dirty) {
                [System.Windows.Forms.MessageBox]::Show(
                    "Bindings changed after the last test. Run Test Bindings again before Apply.",
                    "Bindings changed",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Warning
                ) | Out-Null
                return
            }

            if (-not $wizardState.LastTestPassed) {
                [System.Windows.Forms.MessageBox]::Show(
                    "Current bindings did not pass validation. Fix them and run Test Bindings again.",
                    "Bindings test failed",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Warning
                ) | Out-Null
                return
            }

            $wizardState.AppliedResult = [PSCustomObject]@{
                ResolvedMappings = (& $collectCurrentMappings)
                SavedProfileId   = $wizardState.SavedProfileId
                SavedProfileHash = $wizardState.SavedProfileHash
            }
            $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
            $form.Close()
        }).GetNewClosure())

    $wizardState.Ready = $true
    & $setStatus "Not tested" @("Save Profile to persist the current selection, then run Test Bindings before Apply.") "info"

    $dialogResult = $form.ShowDialog()
    if ($dialogResult -ne [System.Windows.Forms.DialogResult]::OK) {
        throw "Interactive UI binding was cancelled by the user."
    }

    if ($null -ne $wizardState.AppliedResult) {
        return $wizardState.AppliedResult
    }

    return [PSCustomObject]@{
        ResolvedMappings = $resolvedMappings
        SavedProfileId   = $wizardState.SavedProfileId
        SavedProfileHash = $wizardState.SavedProfileHash
    }
}

function Resolve-PbiRequestedModuleBindings {
    param(
        [Parameter(Mandatory = $true)]$Project,
        [Parameter(Mandatory = $true)]$Module,
        $BaseMappings,
        [string]$MappingFile,
        [string]$BindingProfileId,
        [string]$SaveBindingProfileAs,
        [switch]$Interactive,
        [switch]$InteractiveUi,
        [switch]$AcceptSuggested
    )

    $resolvedMappings = ConvertTo-PbiResolvedMappings -Mappings $BaseMappings
    $bindingMode = "default"
    $bindingProfileHash = ""
    $effectiveBindingProfileId = ""
    $suggestionSet = $null

    if ($BindingProfileId) {
        $profileRecord = Get-PbiBindingProfile -Project $Project -ModuleId $Module.ModuleId -ProfileId $BindingProfileId
        $resolvedMappings = Merge-PbiModuleMappings -BaseMapping $resolvedMappings -OverrideMapping $profileRecord.Profile.resolvedMappings
        $bindingMode = "binding-profile"
        $bindingProfileHash = $profileRecord.Hash
        $effectiveBindingProfileId = $profileRecord.Profile.profileId
    }

    if ($MappingFile) {
        $resolvedMappings = Merge-PbiModuleMappings -BaseMapping $resolvedMappings -OverrideMapping (Read-PbiJsonFile -Path $MappingFile)
        if ($bindingMode -eq "default") {
            $bindingMode = "mapping-file"
        }
    }

    if ($Interactive -or $InteractiveUi -or $AcceptSuggested) {
        $suggestionSet = Get-PbiModuleBindingSuggestions -Project $Project -Module $Module -BaseMappings $resolvedMappings
        if ($InteractiveUi) {
            $defaultProfileId = if (-not [string]::IsNullOrWhiteSpace($SaveBindingProfileAs)) {
                $SaveBindingProfileAs
            }
            elseif (-not [string]::IsNullOrWhiteSpace($BindingProfileId)) {
                $BindingProfileId
            }
            else {
                ""
            }

            $wizardResult = Invoke-PbiInteractiveBindingUiWizard -SuggestionSet $suggestionSet -Project $Project -Module $Module -DefaultProfileId $defaultProfileId
            $resolvedMappings = ConvertTo-PbiResolvedMappings -Mappings $wizardResult.ResolvedMappings

            if (-not [string]::IsNullOrWhiteSpace([string]$wizardResult.SavedProfileId)) {
                $effectiveBindingProfileId = [string]$wizardResult.SavedProfileId
                $bindingProfileHash = [string]$wizardResult.SavedProfileHash
            }
        }
        elseif ($Interactive) {
            $resolvedMappings = Invoke-PbiInteractiveBindingWizard -SuggestionSet $suggestionSet
        }
        else {
            $resolvedMappings = Resolve-PbiSuggestedMappings -SuggestionSet $suggestionSet
        }

        if ($InteractiveUi) {
            $bindingMode = "interactive-ui"
        }
        elseif ($Interactive) {
            $bindingMode = "interactive"
        }
        else {
            $bindingMode = "suggested"
        }
    }

    if ($SaveBindingProfileAs -and ($effectiveBindingProfileId -ne $SaveBindingProfileAs)) {
        $savedProfile = Save-PbiBindingProfile -Project $Project -Module $Module -ProfileId $SaveBindingProfileAs -ResolvedMappings $resolvedMappings -BindingMode $bindingMode
        $bindingProfileHash = $savedProfile.Hash
        $effectiveBindingProfileId = $SaveBindingProfileAs
    }

    return [PSCustomObject]@{
        ResolvedMappings   = ConvertTo-PbiResolvedMappings -Mappings $resolvedMappings
        BindingMode        = $bindingMode
        BindingProfileId   = $effectiveBindingProfileId
        BindingProfileHash = $bindingProfileHash
        BindingSelections = Get-PbiModuleBindingSelections -Manifest $Module.Manifest -ResolvedMappings $resolvedMappings
        SuggestionSet      = if ($suggestionSet) { $suggestionSet } else { $null }
    }
}

function Get-PbiBindingMetadataValue {
    param(
        [Parameter(Mandatory = $true)]$ResolvedMappings,
        [Parameter(Mandatory = $true)][string]$BindingKey,
        [Parameter(Mandatory = $true)][string]$PropertyName
    )

    $mappings = ConvertTo-PbiResolvedMappings -Mappings $ResolvedMappings

    if ($mappings.coreMeasures.Contains($BindingKey)) {
        $measureName = [string]$mappings.coreMeasures[$BindingKey]
        switch ($PropertyName) {
            "label" { return $measureName }
            "value" { return $measureName }
            default { return "" }
        }
    }

    if ($mappings.coreColumns.Contains($BindingKey)) {
        $columnReference = [string]$mappings.coreColumns[$BindingKey]
        $columnInfo = ConvertFrom-PbiColumnReference -ColumnReference $columnReference
        switch ($PropertyName) {
            "label" { return $columnInfo.ColumnName }
            "value" { return $columnInfo.Reference }
            "table" { return $columnInfo.TableName }
            "column" { return $columnInfo.ColumnName }
            "queryRef" { return $columnInfo.QueryReference }
            default { return "" }
        }
    }

    return ""
}

function Update-PbiJsonColumnBindingReferences {
    param(
        [Parameter(Mandatory = $true)]$Node,
        [Parameter(Mandatory = $true)]$SourceColumn,
        [Parameter(Mandatory = $true)]$TargetColumn
    )

    if ($null -eq $Node -or $Node -is [string] -or $Node -is [ValueType]) {
        return
    }

    if ($Node -is [System.Collections.IEnumerable] -and -not ($Node -is [System.Collections.IDictionary])) {
        foreach ($item in $Node) {
            Update-PbiJsonColumnBindingReferences -Node $item -SourceColumn $SourceColumn -TargetColumn $TargetColumn
        }

        return
    }

    $propertyNames = @($Node.PSObject.Properties.Name)
    if (($propertyNames -contains "Expression") -and ($propertyNames -contains "Property")) {
        $expressionNode = $Node.Expression
        if ($expressionNode) {
            $expressionPropertyNames = @($expressionNode.PSObject.Properties.Name)
            if ($expressionPropertyNames -contains "SourceRef") {
                $sourceRefNode = $expressionNode.SourceRef
                if ($sourceRefNode) {
                    $sourceRefPropertyNames = @($sourceRefNode.PSObject.Properties.Name)
                    if (($sourceRefPropertyNames -contains "Entity") -and
                        ([string]$sourceRefNode.Entity -eq $SourceColumn.TableName) -and
                        ([string]$Node.Property -eq $SourceColumn.ColumnName)) {
                        $sourceRefNode.Entity = $TargetColumn.TableName
                        $Node.Property = $TargetColumn.ColumnName
                    }
                }
            }
        }
    }

    if (($propertyNames -contains "queryRef") -and ([string]$Node.queryRef -eq $SourceColumn.QueryReference)) {
        $Node.queryRef = $TargetColumn.QueryReference
    }

    if ($propertyNames -contains "nativeQueryRef") {
        if ([string]$Node.nativeQueryRef -eq $SourceColumn.QueryReference) {
            $Node.nativeQueryRef = $TargetColumn.QueryReference
        }
        elseif ([string]$Node.nativeQueryRef -eq $SourceColumn.Reference) {
            $Node.nativeQueryRef = $TargetColumn.Reference
        }
    }

    foreach ($property in $Node.PSObject.Properties) {
        if ($property.Value -is [string]) {
            $updatedValue = [string]$property.Value
            $replacements = @(
                [PSCustomObject]@{
                    Pattern     = ("'''{0}''[{1}]'" -f $SourceColumn.TableName, $SourceColumn.ColumnName)
                    Replacement = ("'''{0}''[{1}]'" -f $TargetColumn.TableName, $TargetColumn.ColumnName)
                },
                [PSCustomObject]@{
                    Pattern     = ("'{0}'[{1}]" -f $SourceColumn.TableName, $SourceColumn.ColumnName)
                    Replacement = ("'{0}'[{1}]" -f $TargetColumn.TableName, $TargetColumn.ColumnName)
                },
                [PSCustomObject]@{
                    Pattern     = $SourceColumn.Reference
                    Replacement = $TargetColumn.Reference
                },
                [PSCustomObject]@{
                    Pattern     = $SourceColumn.QueryReference
                    Replacement = $TargetColumn.QueryReference
                }
            )

            foreach ($replacementItem in $replacements) {
                $updatedValue = $updatedValue.Replace([string]$replacementItem.Pattern, [string]$replacementItem.Replacement)
            }

            if ($updatedValue -ne [string]$property.Value) {
                $property.Value = $updatedValue
            }

            continue
        }

        Update-PbiJsonColumnBindingReferences -Node $property.Value -SourceColumn $SourceColumn -TargetColumn $TargetColumn
    }
}

function Convert-PbiJsonTextWithResolvedColumnMappings {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)]$ResolvedMappings
    )

    try {
        $jsonObject = ConvertFrom-PbiJsonText -Text $Text
    }
    catch {
        return $null
    }

    foreach ($columnMapping in @($ResolvedMappings.coreColumns.GetEnumerator() | Sort-Object { $_.Key.Length } -Descending)) {
        $sourceColumn = ConvertFrom-PbiColumnReference -ColumnReference ([string]$columnMapping.Key)
        $targetColumn = ConvertFrom-PbiColumnReference -ColumnReference ([string]$columnMapping.Value)
        Update-PbiJsonColumnBindingReferences -Node $jsonObject -SourceColumn $sourceColumn -TargetColumn $targetColumn
    }

    return (ConvertTo-PbiJsonText -InputObject $jsonObject)
}

function Expand-PbiBindingTokensInText {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        $ResolvedMappings
    )

    $tokenPattern = "\{\{binding(?<Property>Label|Value|Table|Column|QueryRef):(?<Key>.+?)\}\}"
    return [regex]::Replace($Text, $tokenPattern, [System.Text.RegularExpressions.MatchEvaluator]{
            param($Match)
            $propertyName = switch ($Match.Groups["Property"].Value) {
                "Label" { "label" }
                "Value" { "value" }
                "Table" { "table" }
                "Column" { "column" }
                "QueryRef" { "queryRef" }
                default { "" }
            }

            if ([string]::IsNullOrWhiteSpace($propertyName)) {
                return $Match.Value
            }

            $replacementValue = Get-PbiBindingMetadataValue -ResolvedMappings $ResolvedMappings -BindingKey $Match.Groups["Key"].Value -PropertyName $propertyName
            if ([string]::IsNullOrWhiteSpace($replacementValue)) {
                return $Match.Value
            }

            return $replacementValue
        })
}

function Convert-PbiTextWithResolvedMappings {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        $ResolvedMappings
    )

    $updatedText = $Text
    $mappings = ConvertTo-PbiResolvedMappings -Mappings $ResolvedMappings
    $updatedText = Expand-PbiBindingTokensInText -Text $updatedText -ResolvedMappings $mappings

    foreach ($measureMapping in @($mappings.coreMeasures.GetEnumerator() | Sort-Object { $_.Key.Length } -Descending)) {
        $sourceName = [string]$measureMapping.Key
        $targetName = [string]$measureMapping.Value
        if ([string]::IsNullOrWhiteSpace($targetName) -or ($targetName -eq $sourceName)) {
            continue
        }

        $pattern = "\[{0}\]" -f [regex]::Escape($sourceName)
        $replacement = ("[" + $targetName + "]")
        $updatedText = [regex]::Replace($updatedText, $pattern, [System.Text.RegularExpressions.MatchEvaluator]{
                param($Match)
                return $replacement
            })
    }

    $jsonUpdatedText = Convert-PbiJsonTextWithResolvedColumnMappings -Text $updatedText -ResolvedMappings $mappings
    if ($null -ne $jsonUpdatedText) {
        return $jsonUpdatedText
    }

    foreach ($columnMapping in @($mappings.coreColumns.GetEnumerator() | Sort-Object { $_.Key.Length } -Descending)) {
        $sourceColumn = ConvertFrom-PbiColumnReference -ColumnReference ([string]$columnMapping.Key)
        $targetColumn = ConvertFrom-PbiColumnReference -ColumnReference ([string]$columnMapping.Value)

        $sourceTableQuoted = Get-PbiTmdlIdentifier -Name $sourceColumn.TableName
        $targetTableQuoted = Get-PbiTmdlIdentifier -Name $targetColumn.TableName

        $replacements = @(
            [PSCustomObject]@{
                Pattern     = ("'''" + [regex]::Escape($sourceColumn.TableName) + "''\[" + [regex]::Escape($sourceColumn.ColumnName) + "\]'")
                Replacement = ("'''" + $targetColumn.TableName + "''[" + $targetColumn.ColumnName + "]'")
            },
            [PSCustomObject]@{
                Pattern     = ("'{0}'\[{1}\]" -f [regex]::Escape($sourceColumn.TableName), [regex]::Escape($sourceColumn.ColumnName))
                Replacement = ($targetTableQuoted + "[" + $targetColumn.ColumnName + "]")
            },
            [PSCustomObject]@{
                Pattern     = ("{0}\[{1}\]" -f [regex]::Escape($sourceColumn.TableName), [regex]::Escape($sourceColumn.ColumnName))
                Replacement = ($targetColumn.TableName + "[" + $targetColumn.ColumnName + "]")
            },
            [PSCustomObject]@{
                Pattern     = [regex]::Escape($sourceColumn.QueryReference)
                Replacement = $targetColumn.QueryReference
            }
        )

        foreach ($replacementItem in $replacements) {
            $updatedText = [regex]::Replace($updatedText, $replacementItem.Pattern, $replacementItem.Replacement)
        }
    }

    return $updatedText
}

Export-ModuleMember -Function New-PbiResolvedMappings, ConvertTo-PbiResolvedMappings, Get-PbiResolvedMappingSection, ConvertFrom-PbiColumnReference, Get-PbiModuleBindingContract, Get-PbiBindingContractDefaultMappings, Get-PbiProjectBindingProfiles, Get-PbiBindingProfile, Save-PbiBindingProfile, Get-PbiProjectMeasureCandidates, Get-PbiProjectColumnCandidates, Get-PbiModuleBindingSuggestions, Resolve-PbiSuggestedMappings, Invoke-PbiInteractiveBindingWizard, Invoke-PbiInteractiveBindingUiWizard, Resolve-PbiRequestedModuleBindings, Get-PbiModuleBindingSelections, Convert-PbiTextWithResolvedMappings
