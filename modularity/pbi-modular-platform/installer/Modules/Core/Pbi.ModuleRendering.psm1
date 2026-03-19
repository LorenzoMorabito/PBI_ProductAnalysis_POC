Set-StrictMode -Version Latest

function Get-PbiModuleRenderingStrategy {
    param([Parameter(Mandatory = $true)]$Manifest)

    if (($Manifest.PSObject.Properties.Name -contains "rendering") -and $Manifest.rendering -and $Manifest.rendering.strategy) {
        return [string]$Manifest.rendering.strategy
    }

    return "static"
}

function New-PbiRenderedModuleFileMapping {
    param(
        [string]$TableName,
        [string]$SourcePath,
        [string]$DestinationPath,
        [string]$RelativePath,
        [string]$SourceContent
    )

    return [PSCustomObject]@{
        TableName        = $TableName
        SourcePath       = $SourcePath
        DestinationPath  = $DestinationPath
        RelativePath     = $RelativePath
        SourceContent    = $SourceContent
    }
}

function Get-PbiFlexBindingItems {
    param(
        [Parameter(Mandatory = $true)]$Manifest,
        [Parameter(Mandatory = $true)]$ResolvedMappings,
        [Parameter(Mandatory = $true)][string]$CollectionId
    )

    $selections = Get-PbiModuleBindingSelections -Manifest $Manifest -ResolvedMappings $ResolvedMappings
    if ($selections.Contains($CollectionId)) {
        return @($selections[$CollectionId] | Sort-Object ordinal)
    }

    return @()
}

function Get-PbiFlexVisibleCount {
    param(
        [Parameter(Mandatory = $true)][int]$ItemCount,
        [Parameter(Mandatory = $true)][int]$PreferredCount
    )

    if ($ItemCount -le 0) {
        return 0
    }

    return [Math]::Min($ItemCount, [Math]::Max(1, $PreferredCount))
}

function Get-PbiFlexDimensionBindingTableName {
    param([Parameter(Mandatory = $true)]$Item)

    return (ConvertFrom-PbiColumnReference -ColumnReference $Item.bindingKey).TableName
}

function Get-PbiBindingTokenLiteral {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("Label", "Value", "Table", "Column", "QueryRef")]
        [string]$Property,
        [Parameter(Mandatory = $true)][string]$BindingKey
    )

    return ("{{{{binding{0}:{1}}}}}" -f $Property, $BindingKey)
}

function New-PbiFlexFlatInputsTemplate {
    param([Parameter(Mandatory = $true)]$MeasureItems)

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("table 'MOD Flex Flat Inputs'")
    $lines.Add("")

    for ($index = 0; $index -lt $MeasureItems.Count; $index++) {
        $item = $MeasureItems[$index]
        $measureOrdinal = $index + 1
        $lines.Add(("`tmeasure 'Flat Input Metric {0}' = [{1}]" -f $measureOrdinal, $item.bindingKey))
        $lines.Add("")
    }

    $lines.Add("`tcolumn Column")
    $lines.Add("`t`tisHidden")
    $lines.Add("`t`tformatString: 0")
    $lines.Add("`t`tsummarizeBy: sum")
    $lines.Add("`t`tisNameInferred")
    $lines.Add("`t`tsourceColumn: [Column]")
    $lines.Add("")
    $lines.Add("`tpartition 'MOD Flex Flat Inputs' = calculated")
    $lines.Add("`t`tmode: import")
    $lines.Add("`t`tsource = Row(""Column"", BLANK())")

    return ($lines -join "`r`n")
}

function New-PbiFlexFlatDimensionsTemplate {
    param([Parameter(Mandatory = $true)]$DimensionItems)

    $rows = New-Object System.Collections.Generic.List[string]
    for ($index = 0; $index -lt $DimensionItems.Count; $index++) {
        $item = $DimensionItems[$index]
        $bindingTable = Get-PbiFlexDimensionBindingTableName -Item $item
        $rows.Add(('                ("{0}", NAMEOF(''{1}''[Value]), {2})' -f (Get-PbiBindingTokenLiteral -Property "Label" -BindingKey ([string]$item.bindingKey)), $bindingTable, $index))
    }

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("table 'MOD Flex Flat Dimensions'")
    $lines.Add("")
    $lines.Add("    column 'Flat Dimension'")
    $lines.Add("        summarizeBy: none")
    $lines.Add("        sourceColumn: [Value1]")
    $lines.Add("        sortByColumn: 'Flat Dimension Order'")
    $lines.Add("")
    $lines.Add("        relatedColumnDetails")
    $lines.Add("            groupByColumn: 'Flat Dimension Fields'")
    $lines.Add("")
    $lines.Add("    column 'Flat Dimension Fields'")
    $lines.Add("        isHidden")
    $lines.Add("        summarizeBy: none")
    $lines.Add("        sourceColumn: [Value2]")
    $lines.Add("        sortByColumn: 'Flat Dimension Order'")
    $lines.Add("")
    $lines.Add("        extendedProperty ParameterMetadata =")
    $lines.Add("                {")
    $lines.Add('                  "version": 3,')
    $lines.Add('                  "kind": 2')
    $lines.Add("                }")
    $lines.Add("")
    $lines.Add("    column 'Flat Dimension Order'")
    $lines.Add("        isHidden")
    $lines.Add("        formatString: 0")
    $lines.Add("        summarizeBy: none")
    $lines.Add("        sourceColumn: [Value3]")
    $lines.Add("")
    $lines.Add("    partition 'MOD Flex Flat Dimensions' = calculated")
    $lines.Add("        mode: import")
    $lines.Add("        source =")
    $lines.Add("                {")
    $lines.Add(($rows -join ",`r`n"))
    $lines.Add("                }")

    return (($lines -join "`r`n") + "`r`n")
}

function New-PbiFlexFlatMeasuresTemplate {
    param([Parameter(Mandatory = $true)]$MeasureItems)

    $rows = New-Object System.Collections.Generic.List[string]
    for ($index = 0; $index -lt $MeasureItems.Count; $index++) {
        $item = $MeasureItems[$index]
        $measureOrdinal = $index + 1
        $rows.Add(('                ("{0}", NAMEOF(''MOD Flex Flat Inputs''[Flat Input Metric {1}]), {2})' -f (Get-PbiBindingTokenLiteral -Property "Label" -BindingKey ([string]$item.bindingKey)), $measureOrdinal, $index))
    }

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("table 'MOD Flex Flat Measures'")
    $lines.Add("")
    $lines.Add("    column 'Flat Measure'")
    $lines.Add("        summarizeBy: none")
    $lines.Add("        sourceColumn: [Value1]")
    $lines.Add("        sortByColumn: 'Flat Measure Order'")
    $lines.Add("")
    $lines.Add("        relatedColumnDetails")
    $lines.Add("            groupByColumn: 'Flat Measure Fields'")
    $lines.Add("")
    $lines.Add("    column 'Flat Measure Fields'")
    $lines.Add("        isHidden")
    $lines.Add("        summarizeBy: none")
    $lines.Add("        sourceColumn: [Value2]")
    $lines.Add("        sortByColumn: 'Flat Measure Order'")
    $lines.Add("")
    $lines.Add("        extendedProperty ParameterMetadata =")
    $lines.Add("                {")
    $lines.Add('                  "version": 3,')
    $lines.Add('                  "kind": 2')
    $lines.Add("                }")
    $lines.Add("")
    $lines.Add("    column 'Flat Measure Order'")
    $lines.Add("        isHidden")
    $lines.Add("        formatString: 0")
    $lines.Add("        summarizeBy: none")
    $lines.Add("        sourceColumn: [Value3]")
    $lines.Add("")
    $lines.Add("    partition 'MOD Flex Flat Measures' = calculated")
    $lines.Add("        mode: import")
    $lines.Add("        source =")
    $lines.Add("                {")
    $lines.Add(($rows -join ",`r`n"))
    $lines.Add("                }")

    return (($lines -join "`r`n") + "`r`n")
}

function New-PbiFlexPivotInputsTemplate {
    param([Parameter(Mandatory = $true)]$MeasureItems)

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("table 'MOD Flex Table Inputs'")
    $lines.Add("")

    for ($index = 0; $index -lt $MeasureItems.Count; $index++) {
        $item = $MeasureItems[$index]
        $measureOrdinal = $index + 1
        $lines.Add(("`tmeasure 'Flex Input Metric {0}' = [{1}]" -f $measureOrdinal, $item.bindingKey))
        $lines.Add("")
    }

    $lines.Add("`tcolumn Column")
    $lines.Add("`t`tisHidden")
    $lines.Add("`t`tformatString: 0")
    $lines.Add("`t`tsummarizeBy: sum")
    $lines.Add("`t`tisNameInferred")
    $lines.Add("`t`tsourceColumn: [Column]")
    $lines.Add("")
    $lines.Add("`tpartition 'MOD Flex Table Inputs' = calculated")
    $lines.Add("`t`tmode: import")
    $lines.Add("`t`tsource = Row(""Column"", BLANK())")

    return ($lines -join "`r`n")
}

function New-PbiFlexPivotMeasureSelectorTemplate {
    param([Parameter(Mandatory = $true)]$MeasureItems)

    $rows = New-Object System.Collections.Generic.List[string]
    for ($index = 0; $index -lt $MeasureItems.Count; $index++) {
        $item = $MeasureItems[$index]
        $measureOrdinal = $index + 1
        $rows.Add(('                {"metric_' + $measureOrdinal + '", "{{bindingLabel:' + [string]$item.bindingKey + '}}", "Metric", ' + $measureOrdinal + '}'))
    }

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("table 'MOD Flex Table Measure Selector'")
    $lines.Add("")
    $lines.Add("    column MeasureKey")
    $lines.Add("        isHidden")
    $lines.Add("        summarizeBy: none")
    $lines.Add("        isNameInferred")
    $lines.Add("        sourceColumn: [MeasureKey]")
    $lines.Add("")
    $lines.Add("    column DisplayLabel")
    $lines.Add("        summarizeBy: none")
    $lines.Add("        sortByColumn: MeasureSort")
    $lines.Add("        isNameInferred")
    $lines.Add("        sourceColumn: [DisplayLabel]")
    $lines.Add("")
    $lines.Add("    column Domain")
    $lines.Add("        summarizeBy: none")
    $lines.Add("        isNameInferred")
    $lines.Add("        sourceColumn: [Domain]")
    $lines.Add("")
    $lines.Add("    column MeasureSort")
    $lines.Add("        isHidden")
    $lines.Add("        formatString: 0")
    $lines.Add("        summarizeBy: none")
    $lines.Add("        isNameInferred")
    $lines.Add("        sourceColumn: [MeasureSort]")
    $lines.Add("")
    $lines.Add("    partition 'MOD Flex Table Measure Selector' = calculated")
    $lines.Add("        mode: import")
    $lines.Add('        source = ```')
    $lines.Add("                DATATABLE(")
    $lines.Add('                    "MeasureKey", STRING,')
    $lines.Add('                    "DisplayLabel", STRING,')
    $lines.Add('                    "Domain", STRING,')
    $lines.Add('                    "MeasureSort", INTEGER,')
    $lines.Add("                    {")
    $lines.Add(($rows -join ",`r`n"))
    $lines.Add("                    }")
    $lines.Add("                )")
    $lines.Add('                ```')

    return (($lines -join "`r`n") + "`r`n")
}

function New-PbiFlexPivotAxisTemplate {
    param([Parameter(Mandatory = $true)]$DimensionItems)

    $blocks = New-Object System.Collections.Generic.List[string]
    for ($index = 0; $index -lt $DimensionItems.Count; $index++) {
        $item = $DimensionItems[$index]
        $dimensionOrdinal = $index + 1
        $bindingTable = Get-PbiFlexDimensionBindingTableName -Item $item
        $blocks.Add(@(
                "				    SELECTCOLUMNS(",
                "				        FILTER(",
                ("				            VALUES({0}[Value])," -f $bindingTable),
                ("				            NOT ISBLANK({0}[Value])" -f $bindingTable),
                "				        ),",
                ("				        ""DimensionKey"", ""dimension_{0}""," -f $dimensionOrdinal),
                ("				        ""DimensionLabel"", ""{0}""," -f (Get-PbiBindingTokenLiteral -Property "Label" -BindingKey ([string]$item.bindingKey))),
                ("				        ""DimensionSort"", {0}," -f $dimensionOrdinal),
                ("				        ""AxisLabel"", {0}[Value]" -f $bindingTable),
                "				    )"
            ) -join "`r`n")
    }

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("table 'MOD Flex Table Axis'")
    $lines.Add("")
    $lines.Add("`tcolumn DimensionKey")
    $lines.Add("`t`tisHidden")
    $lines.Add("`t`tsummarizeBy: none")
    $lines.Add("`t`tisNameInferred")
    $lines.Add("`t`tsourceColumn: [DimensionKey]")
    $lines.Add("")
    $lines.Add("`tcolumn DimensionLabel")
    $lines.Add("`t`tsummarizeBy: none")
    $lines.Add("`t`tsortByColumn: DimensionSort")
    $lines.Add("`t`tisNameInferred")
    $lines.Add("`t`tsourceColumn: [DimensionLabel]")
    $lines.Add("")
    $lines.Add("`tcolumn DimensionSort")
    $lines.Add("`t`tisHidden")
    $lines.Add("`t`tformatString: 0")
    $lines.Add("`t`tsummarizeBy: none")
    $lines.Add("`t`tisNameInferred")
    $lines.Add("`t`tsourceColumn: [DimensionSort]")
    $lines.Add("")
    $lines.Add("`tcolumn AxisLabel")
    $lines.Add("`t`tsummarizeBy: none")
    $lines.Add("`t`tisNameInferred")
    $lines.Add("`t`tsourceColumn: [AxisLabel]")
    $lines.Add("")
    $lines.Add("`tpartition 'MOD Flex Table Axis' = calculated")
    $lines.Add("`t`tmode: import")
    $lines.Add("`t`tsource =")
    $lines.Add("`t`t`t`tUNION(")
    $lines.Add(($blocks -join ",`r`n"))
    $lines.Add("`t`t`t`t)")

    return (($lines -join "`r`n") + "`r`n")
}

function New-PbiFlexPivotMetricsTemplate {
    param(
        [Parameter(Mandatory = $true)]$MeasureItems,
        [Parameter(Mandatory = $true)]$DimensionItems
    )

    $measureSwitchRows = New-Object System.Collections.Generic.List[string]
    for ($index = 0; $index -lt $MeasureItems.Count; $index++) {
        $measureOrdinal = $index + 1
        $measureSwitchRows.Add(('			        "metric_{0}", [Flex Input Metric {0}]' -f $measureOrdinal))
    }

    $dimensionSwitchRows = New-Object System.Collections.Generic.List[string]
    for ($index = 0; $index -lt $DimensionItems.Count; $index++) {
        $item = $DimensionItems[$index]
        $dimensionOrdinal = $index + 1
        $bindingTable = Get-PbiFlexDimensionBindingTableName -Item $item
        $row = @(
            ('			    "dimension_{0}",' -f $dimensionOrdinal),
            '			        CALCULATE(',
            '			            BaseMetric,',
            ('			            KEEPFILTERS(TREATAS({{AxisValue}}, {0}[Value]))' -f $bindingTable),
            '			        )'
        ) -join "`r`n"
        $dimensionSwitchRows.Add($row.TrimEnd())
    }

    $fallbackLabel = if ($DimensionItems.Count -gt 0) {
        "{{bindingLabel:$($DimensionItems[0].bindingKey)}}"
    }
    else {
        "Selection"
    }

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("table 'MOD Flex Table Metrics'")
    $lines.Add("")
    $lines.Add("`tmeasure 'Flex Table Selected Value' =")
    $lines.Add("`t`t")
    $lines.Add("`t`tVAR SelectedMeasure = SELECTEDVALUE('MOD Flex Table Measure Selector'[MeasureKey])")
    $lines.Add("`t`tVAR AxisKey = SELECTEDVALUE('MOD Flex Table Axis'[DimensionKey])")
    $lines.Add("`t`tVAR AxisValue = SELECTEDVALUE('MOD Flex Table Axis'[AxisLabel])")
    $lines.Add("`t`tVAR BaseMetric =")
    $lines.Add("`t`t    SWITCH(")
    $lines.Add("`t`t        SelectedMeasure,")
    $lines.Add(($measureSwitchRows -join ",`r`n"))
    $lines.Add("`t`t        BLANK()")
    $lines.Add("`t`t    )")
    $lines.Add("`t`tRETURN")
    $lines.Add("`t`tSWITCH(")
    $lines.Add("`t`t    AxisKey,")
    $lines.Add(($dimensionSwitchRows -join ",`r`n"))
    $lines.Add("`t`t    BLANK()")
    $lines.Add("`t`t)")
    $lines.Add("")
    $lines.Add("`tmeasure 'Flex Table Row Has Data' =")
    $lines.Add("`t`t")
    $lines.Add("`t`tVAR NonBlankMeasureCount =")
    $lines.Add("`t`t    SUMX(")
    $lines.Add("`t`t        VALUES('MOD Flex Table Measure Selector'[MeasureKey]),")
    $lines.Add("`t`t        VAR CurrentMeasureKey = 'MOD Flex Table Measure Selector'[MeasureKey]")
    $lines.Add("`t`t        RETURN")
    $lines.Add("`t`t            IF(")
    $lines.Add("`t`t                NOT ISBLANK(")
    $lines.Add("`t`t                    CALCULATE(")
    $lines.Add("`t`t                        [Flex Table Selected Value],")
    $lines.Add("`t`t                        TREATAS({CurrentMeasureKey}, 'MOD Flex Table Measure Selector'[MeasureKey])")
    $lines.Add("`t`t                    )")
    $lines.Add("`t`t                ),")
    $lines.Add("`t`t                1,")
    $lines.Add("`t`t                0")
    $lines.Add("`t`t            )")
    $lines.Add("`t`t    )")
    $lines.Add("`t`tRETURN")
    $lines.Add("`t`tIF(NonBlankMeasureCount > 0, 1)")
    $lines.Add("")
    $lines.Add("`tmeasure 'Flex Table Title' =")
    $lines.Add("`t`t")
    $lines.Add("`t`tVAR SelectedDimensions =")
    $lines.Add("`t`t    CONCATENATEX(")
    $lines.Add("`t`t        VALUES('MOD Flex Table Axis'[DimensionLabel]),")
    $lines.Add("`t`t        'MOD Flex Table Axis'[DimensionLabel],")
    $lines.Add("`t`t        "", "",")
    $lines.Add("`t`t        'MOD Flex Table Axis'[DimensionSort],")
    $lines.Add("`t`t        ASC")
    $lines.Add("`t`t    )")
    $lines.Add("`t`tRETURN")
    $lines.Add(("`t`t""Flexible Metrics Pivot | "" & COALESCE(SelectedDimensions, ""{0}"")" -f $fallbackLabel))
    $lines.Add("")
    $lines.Add("`tcolumn Column")
    $lines.Add("`t`tisHidden")
    $lines.Add("`t`tformatString: 0")
    $lines.Add("`t`tsummarizeBy: sum")
    $lines.Add("`t`tisNameInferred")
    $lines.Add("`t`tsourceColumn: [Column]")
    $lines.Add("")
    $lines.Add("`tpartition 'MOD Flex Table Metrics' = calculated")
    $lines.Add("`t`tmode: import")
    $lines.Add("`t`tsource = Row(""Column"", BLANK())")

    return (($lines -join "`r`n") + "`r`n")
}

function Get-PbiFlexFlatColumnsSlicerContent {
    param(
        [Parameter(Mandatory = $true)][string]$TemplateContent,
        [Parameter(Mandatory = $true)]$DimensionItems
    )

    $visual = ConvertFrom-PbiJsonText -Text $TemplateContent
    $selectedItems = @($DimensionItems | Select-Object -First (Get-PbiFlexVisibleCount -ItemCount $DimensionItems.Count -PreferredCount 2))
    $values = @()
    $decomposedValues = @()
    $valueMap = @()

    foreach ($item in $selectedItems) {
        $bindingTable = Get-PbiFlexDimensionBindingTableName -Item $item
        $literalValue = ("'''{0}''[Value]'" -f $bindingTable)
        $values += ,(@([ordered]@{ Literal = [ordered]@{ Value = $literalValue } }))
        $decomposedValues += ,(@([ordered]@{ "0" = @([ordered]@{ Literal = [ordered]@{ Value = $literalValue } }) }))
        $valueMap += @([ordered]@{ "0" = (Get-PbiBindingTokenLiteral -Property "Label" -BindingKey ([string]$item.bindingKey)) })
    }

    $whereClause = $visual.visual.objects.general[0].properties.filter.filter.Where[0]
    $whereClause.Condition.In.Values = $values
    $whereClause.Annotations.filterExpressionMetadata.decomposedIdentities.values = $decomposedValues
    $whereClause.Annotations.filterExpressionMetadata.valueMap = $valueMap

    return (ConvertTo-PbiJsonText -InputObject $visual)
}

function Get-PbiFlexFlatMeasuresSlicerContent {
    param(
        [Parameter(Mandatory = $true)][string]$TemplateContent,
        [Parameter(Mandatory = $true)]$MeasureItems
    )

    $visual = ConvertFrom-PbiJsonText -Text $TemplateContent
    $selectedItems = @($MeasureItems | Select-Object -First (Get-PbiFlexVisibleCount -ItemCount $MeasureItems.Count -PreferredCount 2))
    $values = @()
    $decomposedValues = @()
    $valueMap = @()

    for ($index = 0; $index -lt $selectedItems.Count; $index++) {
        $item = $selectedItems[$index]
        $measureOrdinal = $index + 1
        $literalValue = ("'''MOD Flex Flat Inputs''[Flat Input Metric {0}]'" -f $measureOrdinal)
        $values += ,(@([ordered]@{ Literal = [ordered]@{ Value = $literalValue } }))
        $decomposedValues += ,(@([ordered]@{ "0" = @([ordered]@{ Literal = [ordered]@{ Value = $literalValue } }) }))
        $valueMap += @([ordered]@{ "0" = (Get-PbiBindingTokenLiteral -Property "Label" -BindingKey ([string]$item.bindingKey)) })
    }

    $whereClause = $visual.visual.objects.general[0].properties.filter.filter.Where[0]
    $whereClause.Condition.In.Values = $values
    $whereClause.Annotations.filterExpressionMetadata.decomposedIdentities.values = $decomposedValues
    $whereClause.Annotations.filterExpressionMetadata.valueMap = $valueMap

    return (ConvertTo-PbiJsonText -InputObject $visual)
}

function Get-PbiFlexFlatTableVisualContent {
    param(
        [Parameter(Mandatory = $true)][string]$TemplateContent,
        [Parameter(Mandatory = $true)]$DimensionItems,
        [Parameter(Mandatory = $true)]$MeasureItems
    )

    $visual = ConvertFrom-PbiJsonText -Text $TemplateContent
    $visibleDimensionCount = Get-PbiFlexVisibleCount -ItemCount $DimensionItems.Count -PreferredCount 2
    $visibleMeasureCount = Get-PbiFlexVisibleCount -ItemCount $MeasureItems.Count -PreferredCount 2
    $projections = @()

    for ($index = 0; $index -lt $visibleDimensionCount; $index++) {
        $item = $DimensionItems[$index]
        $bindingTable = Get-PbiFlexDimensionBindingTableName -Item $item
        $projections += @([ordered]@{
                field = [ordered]@{
                    Column = [ordered]@{
                        Expression = [ordered]@{
                            SourceRef = [ordered]@{
                                Entity = $bindingTable
                            }
                        }
                        Property = "Value"
                    }
                }
                queryRef = ("{0}.Value" -f $bindingTable)
                nativeQueryRef = (Get-PbiBindingTokenLiteral -Property "QueryRef" -BindingKey ([string]$item.bindingKey))
                displayName = (Get-PbiBindingTokenLiteral -Property "Label" -BindingKey ([string]$item.bindingKey))
            })
    }

    for ($index = 0; $index -lt $visibleMeasureCount; $index++) {
        $item = $MeasureItems[$index]
        $measureOrdinal = $index + 1
        $projections += @([ordered]@{
                field = [ordered]@{
                    Measure = [ordered]@{
                        Expression = [ordered]@{
                            SourceRef = [ordered]@{
                                Entity = "MOD Flex Flat Inputs"
                            }
                        }
                        Property = ("Flat Input Metric {0}" -f $measureOrdinal)
                    }
                }
                queryRef = ("MOD Flex Flat Inputs.Flat Input Metric {0}" -f $measureOrdinal)
                nativeQueryRef = (Get-PbiBindingTokenLiteral -Property "Label" -BindingKey ([string]$item.bindingKey))
                displayName = (Get-PbiBindingTokenLiteral -Property "Label" -BindingKey ([string]$item.bindingKey))
            })
    }

    $visual.visual.query.queryState.Values.projections = $projections
    $visual.visual.query.queryState.Values.fieldParameters = @(
        [ordered]@{
            parameterExpr = [ordered]@{
                Column = [ordered]@{
                    Expression = [ordered]@{
                        SourceRef = [ordered]@{
                            Entity = "MOD Flex Flat Dimensions"
                        }
                    }
                    Property = "Flat Dimension"
                }
            }
            index = 0
            length = $visibleDimensionCount
        },
        [ordered]@{
            parameterExpr = [ordered]@{
                Column = [ordered]@{
                    Expression = [ordered]@{
                        SourceRef = [ordered]@{
                            Entity = "MOD Flex Flat Measures"
                        }
                    }
                    Property = "Flat Measure"
                }
            }
            index = $visibleDimensionCount
            length = $visibleMeasureCount
        }
    )

    return (ConvertTo-PbiJsonText -InputObject $visual)
}

function Get-PbiFlexPivotDimensionSlicerContent {
    param(
        [Parameter(Mandatory = $true)][string]$TemplateContent,
        [Parameter(Mandatory = $true)]$DimensionItems
    )

    $visual = ConvertFrom-PbiJsonText -Text $TemplateContent
    $selectedItems = @($DimensionItems | Select-Object -First (Get-PbiFlexVisibleCount -ItemCount $DimensionItems.Count -PreferredCount 2))
    $values = @()
    foreach ($item in $selectedItems) {
        $values += ,(@([ordered]@{ Literal = [ordered]@{ Value = ("'" + (Get-PbiBindingTokenLiteral -Property "Label" -BindingKey ([string]$item.bindingKey)) + "'") } }))
    }

    $visual.visual.objects.general[0].properties.filter.filter.Where[0].Condition.In.Values = $values
    return (ConvertTo-PbiJsonText -InputObject $visual)
}

function Get-PbiFlexPivotMeasureSlicerContent {
    param(
        [Parameter(Mandatory = $true)][string]$TemplateContent,
        [Parameter(Mandatory = $true)]$MeasureItems
    )

    $visual = ConvertFrom-PbiJsonText -Text $TemplateContent
    $selectedItems = @($MeasureItems | Select-Object -First (Get-PbiFlexVisibleCount -ItemCount $MeasureItems.Count -PreferredCount 3))
    $values = @()
    foreach ($item in $selectedItems) {
        $values += ,(@([ordered]@{ Literal = [ordered]@{ Value = ("'" + (Get-PbiBindingTokenLiteral -Property "Label" -BindingKey ([string]$item.bindingKey)) + "'") } }))
    }

    $visual.visual.objects.general[0].properties.filter.filter.Where[0].Condition.In.Values = $values
    return (ConvertTo-PbiJsonText -InputObject $visual)
}

function Get-PbiRenderedFlexReportFiles {
    param(
        [Parameter(Mandatory = $true)]$Project,
        [Parameter(Mandatory = $true)]$Module,
        [Parameter(Mandatory = $true)]$Manifest,
        [Parameter(Mandatory = $true)]$ResolvedMappings,
        [Parameter(Mandatory = $true)][scriptblock]$DynamicContentResolver
    )

    $sourceReportPath = Join-Path $Module.PackageRoot "report"
    $destinationPagePath = Get-PbiPageDestinationRoot -Project $Project -PageName $Manifest.provides.reportPage.name
    $mappings = @()

    foreach ($sourceFile in (Get-ChildItem -Path $sourceReportPath -Recurse -File -ErrorAction SilentlyContinue)) {
        $relativeFilePath = (Get-PbiRelativePath -BasePath $sourceReportPath -Path $sourceFile.FullName).Replace("/", "\")
        $destinationFilePath = Join-Path $destinationPagePath $relativeFilePath
        $sourceContent = Get-Content -Path $sourceFile.FullName -Raw
        $dynamicContent = & $DynamicContentResolver $relativeFilePath $sourceContent
        $contentToRender = if ($dynamicContent) { $dynamicContent } else { $sourceContent }
        $finalContent = Convert-PbiTextWithResolvedMappings -Text $contentToRender -ResolvedMappings $ResolvedMappings
        $mappings += (New-PbiRenderedModuleFileMapping -SourcePath $sourceFile.FullName -DestinationPath $destinationFilePath -RelativePath (Get-PbiRelativePath -BasePath $Project.ProjectRoot -Path $destinationFilePath) -SourceContent $finalContent)
    }

    return @($mappings)
}

function Get-PbiRenderedFlexFlatSemanticAssets {
    param(
        [Parameter(Mandatory = $true)]$Project,
        [Parameter(Mandatory = $true)]$Module,
        [Parameter(Mandatory = $true)]$Manifest,
        [Parameter(Mandatory = $true)]$ResolvedMappings
    )

    $dimensionItems = @(Get-PbiFlexBindingItems -Manifest $Manifest -ResolvedMappings $ResolvedMappings -CollectionId "dimensions")
    $measureItems = @(Get-PbiFlexBindingItems -Manifest $Manifest -ResolvedMappings $ResolvedMappings -CollectionId "measures")
    $tableTemplates = [ordered]@{
        "MOD Flex Flat Inputs"     = (New-PbiFlexFlatInputsTemplate -MeasureItems $measureItems)
        "MOD Flex Flat Dimensions" = (New-PbiFlexFlatDimensionsTemplate -DimensionItems $dimensionItems)
        "MOD Flex Flat Measures"   = (New-PbiFlexFlatMeasuresTemplate -MeasureItems $measureItems)
    }

    $mappings = @()
    foreach ($tableName in @($Manifest.provides.semanticTables)) {
        $destinationPath = Get-PbiTableDefinitionPath -Project $Project -TableName $tableName
        $sourcePath = Join-Path (Join-Path $Module.PackageRoot "semantic") ($tableName + ".tmdl")
        $renderedContent = Convert-PbiTextWithResolvedMappings -Text $tableTemplates[$tableName] -ResolvedMappings $ResolvedMappings
        $mappings += (New-PbiRenderedModuleFileMapping -TableName $tableName -SourcePath $sourcePath -DestinationPath $destinationPath -RelativePath (Get-PbiRelativePath -BasePath $Project.ProjectRoot -Path $destinationPath) -SourceContent $renderedContent)
    }

    return @($mappings)
}

function Get-PbiRenderedFlexFlatReportAssets {
    param(
        [Parameter(Mandatory = $true)]$Project,
        [Parameter(Mandatory = $true)]$Module,
        [Parameter(Mandatory = $true)]$Manifest,
        [Parameter(Mandatory = $true)]$ResolvedMappings
    )

    $dimensionItems = @(Get-PbiFlexBindingItems -Manifest $Manifest -ResolvedMappings $ResolvedMappings -CollectionId "dimensions")
    $measureItems = @(Get-PbiFlexBindingItems -Manifest $Manifest -ResolvedMappings $ResolvedMappings -CollectionId "measures")

    return @(Get-PbiRenderedFlexReportFiles -Project $Project -Module $Module -Manifest $Manifest -ResolvedMappings $ResolvedMappings -DynamicContentResolver {
            param($RelativeFilePath, $TemplateContent)

            switch ($RelativeFilePath) {
                "visuals\flex_flat_columns_slicer\visual.json" { return (Get-PbiFlexFlatColumnsSlicerContent -TemplateContent $TemplateContent -DimensionItems $dimensionItems) }
                "visuals\flex_flat_measures_slicer\visual.json" { return (Get-PbiFlexFlatMeasuresSlicerContent -TemplateContent $TemplateContent -MeasureItems $measureItems) }
                "visuals\flex_flat_table\visual.json" { return (Get-PbiFlexFlatTableVisualContent -TemplateContent $TemplateContent -DimensionItems $dimensionItems -MeasureItems $measureItems) }
                default { return $TemplateContent }
            }
        })
}

function Get-PbiRenderedFlexPivotSemanticAssets {
    param(
        [Parameter(Mandatory = $true)]$Project,
        [Parameter(Mandatory = $true)]$Module,
        [Parameter(Mandatory = $true)]$Manifest,
        [Parameter(Mandatory = $true)]$ResolvedMappings
    )

    $dimensionItems = @(Get-PbiFlexBindingItems -Manifest $Manifest -ResolvedMappings $ResolvedMappings -CollectionId "dimensions")
    $measureItems = @(Get-PbiFlexBindingItems -Manifest $Manifest -ResolvedMappings $ResolvedMappings -CollectionId "measures")
    $tableTemplates = [ordered]@{
        "MOD Flex Table Inputs"           = (New-PbiFlexPivotInputsTemplate -MeasureItems $measureItems)
        "MOD Flex Table Measure Selector" = (New-PbiFlexPivotMeasureSelectorTemplate -MeasureItems $measureItems)
        "MOD Flex Table Axis"             = (New-PbiFlexPivotAxisTemplate -DimensionItems $dimensionItems)
        "MOD Flex Table Metrics"          = (New-PbiFlexPivotMetricsTemplate -MeasureItems $measureItems -DimensionItems $dimensionItems)
    }

    $mappings = @()
    foreach ($tableName in @($Manifest.provides.semanticTables)) {
        $destinationPath = Get-PbiTableDefinitionPath -Project $Project -TableName $tableName
        $sourcePath = Join-Path (Join-Path $Module.PackageRoot "semantic") ($tableName + ".tmdl")
        $renderedContent = Convert-PbiTextWithResolvedMappings -Text $tableTemplates[$tableName] -ResolvedMappings $ResolvedMappings
        $mappings += (New-PbiRenderedModuleFileMapping -TableName $tableName -SourcePath $sourcePath -DestinationPath $destinationPath -RelativePath (Get-PbiRelativePath -BasePath $Project.ProjectRoot -Path $destinationPath) -SourceContent $renderedContent)
    }

    return @($mappings)
}

function Get-PbiRenderedFlexPivotReportAssets {
    param(
        [Parameter(Mandatory = $true)]$Project,
        [Parameter(Mandatory = $true)]$Module,
        [Parameter(Mandatory = $true)]$Manifest,
        [Parameter(Mandatory = $true)]$ResolvedMappings
    )

    $dimensionItems = @(Get-PbiFlexBindingItems -Manifest $Manifest -ResolvedMappings $ResolvedMappings -CollectionId "dimensions")
    $measureItems = @(Get-PbiFlexBindingItems -Manifest $Manifest -ResolvedMappings $ResolvedMappings -CollectionId "measures")

    return @(Get-PbiRenderedFlexReportFiles -Project $Project -Module $Module -Manifest $Manifest -ResolvedMappings $ResolvedMappings -DynamicContentResolver {
            param($RelativeFilePath, $TemplateContent)

            switch ($RelativeFilePath) {
                "visuals\flex_table_dimension_slicer\visual.json" { return (Get-PbiFlexPivotDimensionSlicerContent -TemplateContent $TemplateContent -DimensionItems $dimensionItems) }
                "visuals\flex_table_measure_slicer\visual.json" { return (Get-PbiFlexPivotMeasureSlicerContent -TemplateContent $TemplateContent -MeasureItems $measureItems) }
                default { return $TemplateContent }
            }
        })
}

function Get-PbiRenderedModuleSemanticAssets {
    param(
        [Parameter(Mandatory = $true)]$Project,
        [Parameter(Mandatory = $true)]$Module,
        [Parameter(Mandatory = $true)]$Manifest,
        $ResolvedMappings
    )

    if (-not $ResolvedMappings) {
        return @()
    }

    switch (Get-PbiModuleRenderingStrategy -Manifest $Manifest) {
        "flex-flat" { return @(Get-PbiRenderedFlexFlatSemanticAssets -Project $Project -Module $Module -Manifest $Manifest -ResolvedMappings $ResolvedMappings) }
        "flex-pivot" { return @(Get-PbiRenderedFlexPivotSemanticAssets -Project $Project -Module $Module -Manifest $Manifest -ResolvedMappings $ResolvedMappings) }
        default { return @() }
    }
}

function Get-PbiRenderedModuleReportAssets {
    param(
        [Parameter(Mandatory = $true)]$Project,
        [Parameter(Mandatory = $true)]$Module,
        [Parameter(Mandatory = $true)]$Manifest,
        $ResolvedMappings
    )

    if (-not $ResolvedMappings) {
        return @()
    }

    switch (Get-PbiModuleRenderingStrategy -Manifest $Manifest) {
        "flex-flat" { return @(Get-PbiRenderedFlexFlatReportAssets -Project $Project -Module $Module -Manifest $Manifest -ResolvedMappings $ResolvedMappings) }
        "flex-pivot" { return @(Get-PbiRenderedFlexPivotReportAssets -Project $Project -Module $Module -Manifest $Manifest -ResolvedMappings $ResolvedMappings) }
        default { return @() }
    }
}

Export-ModuleMember -Function Get-PbiModuleRenderingStrategy, Get-PbiRenderedModuleSemanticAssets, Get-PbiRenderedModuleReportAssets
