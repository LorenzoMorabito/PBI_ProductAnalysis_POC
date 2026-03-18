function Resolve-PbiMarketingModuleMapping {
    param(
        [Parameter(Mandatory = $true)]$Manifest,
        $OverrideMapping
    )

    $measureMappings = [ordered]@{}
    $columnMappings = [ordered]@{}

    foreach ($measureName in @($Manifest.requires.coreMeasures)) {
        $measureMappings[$measureName] = $measureName
    }

    foreach ($columnReference in @($Manifest.requires.coreColumns)) {
        $columnMappings[$columnReference] = $columnReference
    }

    if ($OverrideMapping) {
        if ($OverrideMapping.coreMeasures) {
            foreach ($property in $OverrideMapping.coreMeasures.PSObject.Properties) {
                $measureMappings[$property.Name] = $property.Value
            }
        }

        if ($OverrideMapping.coreColumns) {
            foreach ($property in $OverrideMapping.coreColumns.PSObject.Properties) {
                $columnMappings[$property.Name] = $property.Value
            }
        }
    }

    return [ordered]@{
        coreMeasures = $measureMappings
        coreColumns  = $columnMappings
    }
}

Export-ModuleMember -Function Resolve-PbiMarketingModuleMapping
