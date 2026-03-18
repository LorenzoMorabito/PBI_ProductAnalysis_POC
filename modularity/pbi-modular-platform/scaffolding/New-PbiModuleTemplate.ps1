[CmdletBinding()]
param(
    [string]$WorkspaceRoot,
    [Parameter(Mandatory = $true)][string]$Domain,
    [Parameter(Mandatory = $true)][string]$ModuleId,
    [string]$DisplayName,
    [ValidateSet("report-only", "semantic")]
    [string]$Type = "semantic",
    [ValidateSet("report-only", "semantic-light", "semantic-heavy")]
    [string]$Classification,
    [string]$OutputRoot,
    [switch]$IncludeReportPage,
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$platformRoot = Split-Path -Parent $scriptRoot
$runtimeModulePath = Join-Path $platformRoot "installer/Modules/Core/Pbi.Runtime.psm1"
Import-Module $runtimeModulePath -Force -DisableNameChecking

$resolvedWorkspaceRoot = Get-PbiInstallerWorkspaceRoot -WorkspaceRoot $WorkspaceRoot -ScriptRoot $platformRoot
$modularityRoot = if (Test-Path (Join-Path $resolvedWorkspaceRoot "modularity")) { Join-Path $resolvedWorkspaceRoot "modularity" } else { $resolvedWorkspaceRoot }
$domainRoot = Join-Path $modularityRoot ("pbi-" + $Domain + "-domain")

if (-not (Test-Path $domainRoot)) {
    throw "Domain root '$domainRoot' does not exist."
}

if (-not $DisplayName) {
    $DisplayName = (($ModuleId -split "_") | ForEach-Object {
        if ($_.Length -gt 0) {
            $_.Substring(0, 1).ToUpperInvariant() + $_.Substring(1)
        }
    }) -join " "
}

if (-not $Classification) {
    $Classification = if ($Type -eq "report-only") { "report-only" } else { "semantic-light" }
}

if (-not $OutputRoot) {
    $OutputRoot = Join-Path $domainRoot ("packages/" + $ModuleId)
}

if ((Test-Path $OutputRoot) -and -not $Force) {
    throw "Target module path '$OutputRoot' already exists. Use -Force to overwrite."
}

if (Test-Path $OutputRoot) {
    Remove-Item -Path $OutputRoot -Recurse -Force
}

$semanticImpact = if ($Type -eq "report-only") { "none" } else { "additive" }
$semanticTables = if ($Type -eq "semantic") { @("MOD " + $DisplayName + " Placeholder") } else { @() }
$reportPage = if ($Type -eq "report-only" -or $IncludeReportPage) {
    [ordered]@{
        name        = ($ModuleId + "_page")
        displayName = $DisplayName
    }
}
else {
    $null
}

$manifest = [ordered]@{
    moduleId       = $ModuleId
    version        = "0.1.0"
    domain         = $Domain
    type           = $Type
    classification = $Classification
    dependencies   = [ordered]@{
        modules      = @()
        capabilities = @()
    }
    semanticImpact = $semanticImpact
    status         = "prototype"
    description    = ("TODO: describe module '{0}'." -f $DisplayName)
    requires       = [ordered]@{
        coreMeasures = @()
        coreColumns  = @()
    }
    provides       = [ordered]@{
        semanticTables = @($semanticTables)
    }
}

if ($reportPage) {
    $manifest.provides["reportPage"] = $reportPage
}

New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null
Set-Content -Path (Join-Path $OutputRoot "manifest.json") -Value (ConvertTo-PbiJsonText -InputObject $manifest) -Encoding utf8

$readme = @(
    ("# {0}" -f $DisplayName),
    "",
    ("Module scaffold generated for `{0}`." -f $ModuleId),
    "",
    "Next steps:",
    "- complete `manifest.json` requirements and provided objects",
    "- replace placeholder semantic/report assets",
    "- add README notes and compatibility info"
) -join "`r`n"
Set-Content -Path (Join-Path $OutputRoot "README.md") -Value $readme -Encoding utf8

if ($Type -eq "semantic") {
    $semanticRoot = Join-Path $OutputRoot "semantic"
    New-Item -ItemType Directory -Path $semanticRoot -Force | Out-Null
    $tableName = $semanticTables[0]
    $tmdl = @(
        ("table '{0}'" -f $tableName),
        "",
        "    column Placeholder",
        "        dataType: string",
        "",
        ("    partition '{0}' = calculated" -f $tableName),
        "        mode: import",
        "        source = DATATABLE(""Placeholder"", STRING, {{ { ""TODO"" } }})"
    ) -join "`r`n"
    Set-Content -Path (Join-Path $semanticRoot ($tableName + ".tmdl")) -Value $tmdl -Encoding utf8
}

if ($reportPage) {
    $reportRoot = Join-Path $OutputRoot "report"
    New-Item -ItemType Directory -Path $reportRoot -Force | Out-Null
    Set-Content -Path (Join-Path $reportRoot "page.json") -Value "{`"name`":`"$($reportPage.name)`",`"displayName`":`"$($reportPage.displayName)`"}" -Encoding utf8
}

Write-Host ("Generated module scaffold at {0}" -f $OutputRoot)
