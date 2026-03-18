Set-StrictMode -Version Latest

function Get-PbiPlatformRootFromSchemaModule {
    $modulesRoot = Split-Path -Parent $PSScriptRoot
    $installerRoot = Split-Path -Parent $modulesRoot
    return (Split-Path -Parent $installerRoot)
}

function Get-PbiModuleManifestSchemaPath {
    return (Join-Path (Get-PbiPlatformRootFromSchemaModule) "schemas/module-manifest.schema.json")
}

function Get-PbiInstalledModulesSchemaPath {
    return (Join-Path (Get-PbiPlatformRootFromSchemaModule) "schemas/installed-modules.schema.json")
}

function Get-PbiSchemaObjectPropertyNames {
    param([Parameter(Mandatory = $true)]$Object)

    if ($Object -is [System.Collections.IDictionary]) {
        return @($Object.Keys)
    }

    return @($Object.PSObject.Properties | ForEach-Object { $_.Name })
}

function Get-PbiSchemaObjectPropertyValue {
    param(
        [Parameter(Mandatory = $true)]$Object,
        [Parameter(Mandatory = $true)][string]$PropertyName
    )

    if ($Object -is [System.Collections.IDictionary]) {
        $value = $Object[$PropertyName]
        if ($value -is [array]) {
            return ,$value
        }

        return $value
    }

    $property = $Object.PSObject.Properties | Where-Object { $_.Name -eq $PropertyName } | Select-Object -First 1
    if (-not $property) {
        return $null
    }

    if ($property.Value -is [array]) {
        return ,$property.Value
    }

    return $property.Value
}

function Test-PbiSchemaArrayLike {
    param([Parameter(Mandatory = $true)]$Value)

    if ($Value -is [string]) {
        return $false
    }

    return ($Value -is [System.Collections.IEnumerable])
}

function New-PbiSchemaValidationError {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Message
    )

    return [PSCustomObject]@{
        Path    = $Path
        Message = $Message
    }
}

function Test-PbiValueAgainstSchema {
    param(
        $Value,
        [Parameter(Mandatory = $true)]$Schema,
        [string]$Path = "$"
    )

    $errors = New-Object System.Collections.Generic.List[object]

    if ($null -eq $Value) {
        $errors.Add((New-PbiSchemaValidationError -Path $Path -Message "Value cannot be null."))
        return $errors.ToArray()
    }

    if ($Schema.PSObject.Properties.Name -contains "enum") {
        $allowedValues = @($Schema.enum)
        if ($allowedValues -notcontains $Value) {
            $errors.Add((New-PbiSchemaValidationError -Path $Path -Message ("Value '{0}' is not part of enum [{1}]." -f $Value, ($allowedValues -join ", "))))
            return $errors.ToArray()
        }
    }

    if ($Schema.PSObject.Properties.Name -contains "const") {
        if ($Value -ne $Schema.const) {
            $errors.Add((New-PbiSchemaValidationError -Path $Path -Message ("Value must equal '{0}'." -f $Schema.const)))
            return $errors.ToArray()
        }
    }

    if (-not ($Schema.PSObject.Properties.Name -contains "type")) {
        return $errors.ToArray()
    }

    switch ($Schema.type) {
        "object" {
            $isObject = ($Value -is [System.Collections.IDictionary]) -or ($Value -is [pscustomobject]) -or ($Value -is [System.Management.Automation.PSCustomObject])
            if (-not $isObject) {
                $errors.Add((New-PbiSchemaValidationError -Path $Path -Message "Value must be an object."))
                return $errors.ToArray()
            }

            $propertyNames = @(Get-PbiSchemaObjectPropertyNames -Object $Value)
            $schemaPropertyNames = if ($Schema.PSObject.Properties.Name -contains "properties") { @(Get-PbiSchemaObjectPropertyNames -Object $Schema.properties) } else { @() }

            foreach ($requiredProperty in $(if ($Schema.PSObject.Properties.Name -contains "required") { @($Schema.required) } else { @() })) {
                if ($propertyNames -notcontains $requiredProperty) {
                    $errors.Add((New-PbiSchemaValidationError -Path $Path -Message ("Missing required property '{0}'." -f $requiredProperty)))
                }
            }

            foreach ($propertyName in $propertyNames) {
                if ($schemaPropertyNames -contains $propertyName) {
                    $childSchema = Get-PbiSchemaObjectPropertyValue -Object $Schema.properties -PropertyName $propertyName
                    $childValue = Get-PbiSchemaObjectPropertyValue -Object $Value -PropertyName $propertyName
                    $childParams = @{
                        Value  = $childValue
                        Schema = $childSchema
                        Path   = ($Path + "." + $propertyName)
                    }
                    foreach ($childError in (Test-PbiValueAgainstSchema @childParams)) {
                        $errors.Add($childError)
                    }
                }
                elseif (($Schema.PSObject.Properties.Name -contains "additionalProperties") -and ($Schema.additionalProperties -is [bool]) -and (-not $Schema.additionalProperties)) {
                    $errors.Add((New-PbiSchemaValidationError -Path ($Path + "." + $propertyName) -Message "Property is not allowed by the contract."))
                }
            }
        }
        "array" {
            if (-not (Test-PbiSchemaArrayLike -Value $Value)) {
                $errors.Add((New-PbiSchemaValidationError -Path $Path -Message "Value must be an array."))
                return $errors.ToArray()
            }

            $items = @($Value)
            if (($Schema.PSObject.Properties.Name -contains "minItems") -and ($items.Count -lt [int]$Schema.minItems)) {
                $errors.Add((New-PbiSchemaValidationError -Path $Path -Message ("Array must contain at least {0} item(s)." -f $Schema.minItems)))
            }

            if ($Schema.PSObject.Properties.Name -contains "items") {
                for ($index = 0; $index -lt $items.Count; $index++) {
                    $childParams = @{
                        Value  = $items[$index]
                        Schema = $Schema.items
                        Path   = ("{0}[{1}]" -f $Path, $index)
                    }
                    foreach ($childError in (Test-PbiValueAgainstSchema @childParams)) {
                        $errors.Add($childError)
                    }
                }
            }
        }
        "string" {
            if ($Value -isnot [string]) {
                $errors.Add((New-PbiSchemaValidationError -Path $Path -Message "Value must be a string."))
                return $errors.ToArray()
            }

            if (($Schema.PSObject.Properties.Name -contains "minLength") -and ($Value.Length -lt [int]$Schema.minLength)) {
                $errors.Add((New-PbiSchemaValidationError -Path $Path -Message ("String length must be at least {0}." -f $Schema.minLength)))
            }

            if (($Schema.PSObject.Properties.Name -contains "pattern") -and ($Value -notmatch $Schema.pattern)) {
                $errors.Add((New-PbiSchemaValidationError -Path $Path -Message ("Value '{0}' does not match pattern '{1}'." -f $Value, $Schema.pattern)))
            }
        }
        "boolean" {
            if ($Value -isnot [bool]) {
                $errors.Add((New-PbiSchemaValidationError -Path $Path -Message "Value must be a boolean."))
            }
        }
        "integer" {
            if (($Value -isnot [int]) -and ($Value -isnot [long])) {
                $errors.Add((New-PbiSchemaValidationError -Path $Path -Message "Value must be an integer."))
            }
        }
        "number" {
            if (($Value -isnot [int]) -and ($Value -isnot [long]) -and ($Value -isnot [double]) -and ($Value -isnot [decimal])) {
                $errors.Add((New-PbiSchemaValidationError -Path $Path -Message "Value must be a number."))
            }
        }
    }

    return $errors.ToArray()
}

function Get-PbiSchemaValidationMessage {
    param([Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Errors)

    return (($Errors | ForEach-Object { "{0}: {1}" -f $_.Path, $_.Message }) -join " ")
}

function Test-PbiModuleManifestContract {
    param(
        [Parameter(Mandatory = $true)]$Manifest,
        [Parameter(Mandatory = $true)][string]$ManifestPath
    )

    $errors = New-Object System.Collections.Generic.List[object]
    $semanticTables = @($Manifest.provides.semanticTables)
    $reportPage = $Manifest.provides.reportPage

    if ($Manifest.type -eq "report-only") {
        if ($Manifest.classification -ne "report-only") {
            $errors.Add((New-PbiSchemaValidationError -Path "$.classification" -Message "Report-only modules must use classification 'report-only'."))
        }

        if ($Manifest.semanticImpact -ne "none") {
            $errors.Add((New-PbiSchemaValidationError -Path "$.semanticImpact" -Message "Report-only modules must use semanticImpact 'none'."))
        }

        if ($semanticTables.Count -gt 0) {
            $errors.Add((New-PbiSchemaValidationError -Path "$.provides.semanticTables" -Message "Report-only modules cannot declare semantic tables."))
        }

        if (-not $reportPage) {
            $errors.Add((New-PbiSchemaValidationError -Path "$.provides.reportPage" -Message "Report-only modules must declare a report page."))
        }
    }

    if ($Manifest.type -eq "semantic") {
        if ($Manifest.classification -eq "report-only") {
            $errors.Add((New-PbiSchemaValidationError -Path "$.classification" -Message "Semantic modules cannot use classification 'report-only'."))
        }

        if ($Manifest.semanticImpact -eq "none") {
            $errors.Add((New-PbiSchemaValidationError -Path "$.semanticImpact" -Message "Semantic modules must declare an additive or invasive semantic impact."))
        }

        if ($semanticTables.Count -eq 0) {
            $errors.Add((New-PbiSchemaValidationError -Path "$.provides.semanticTables" -Message "Semantic modules must provide at least one semantic table."))
        }
    }

    if (($Manifest.classification -eq "semantic-light") -and ($Manifest.semanticImpact -ne "additive")) {
        $errors.Add((New-PbiSchemaValidationError -Path "$.semanticImpact" -Message "semantic-light modules must declare semanticImpact 'additive'."))
    }

    if (($Manifest.semanticImpact -eq "invasive") -and ($Manifest.classification -ne "semantic-heavy")) {
        $errors.Add((New-PbiSchemaValidationError -Path "$.classification" -Message "semanticImpact 'invasive' is allowed only for semantic-heavy modules."))
    }

    if ($errors.Count -gt 0) {
        throw ("Manifest {0} violates the governed contract. {1}" -f $ManifestPath, (Get-PbiSchemaValidationMessage -Errors $errors.ToArray()))
    }
}

function Test-PbiModuleManifestSchema {
    param(
        [Parameter(Mandatory = $true)]$Manifest,
        [Parameter(Mandatory = $true)][string]$ManifestPath
    )

    $schema = Read-PbiJsonFile -Path (Get-PbiModuleManifestSchemaPath)
    $errors = @(Test-PbiValueAgainstSchema -Value $Manifest -Schema $schema)
    if ($errors.Count -gt 0) {
        throw ("Manifest {0} does not conform to schema. {1}" -f $ManifestPath, (Get-PbiSchemaValidationMessage -Errors $errors))
    }

    Test-PbiModuleManifestContract -Manifest $Manifest -ManifestPath $ManifestPath
}

function Test-PbiInstalledModulesStateSchema {
    param(
        [Parameter(Mandatory = $true)]$State,
        [Parameter(Mandatory = $true)][string]$StatePath
    )

    $schema = Read-PbiJsonFile -Path (Get-PbiInstalledModulesSchemaPath)
    $errors = @(Test-PbiValueAgainstSchema -Value $State -Schema $schema)
    if ($errors.Count -gt 0) {
        throw ("Installed state {0} does not conform to schema. {1}" -f $StatePath, (Get-PbiSchemaValidationMessage -Errors $errors))
    }
}

Export-ModuleMember -Function Get-PbiModuleManifestSchemaPath, Get-PbiInstalledModulesSchemaPath, Test-PbiModuleManifestSchema, Test-PbiInstalledModulesStateSchema
