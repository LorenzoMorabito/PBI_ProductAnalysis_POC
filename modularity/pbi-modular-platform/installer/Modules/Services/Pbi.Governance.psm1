Set-StrictMode -Version Latest

function Get-PbiGovernanceStatusRank {
    param([string]$Status)

    if ([string]::IsNullOrWhiteSpace($Status)) {
        return -1
    }

    switch ($Status.ToUpperInvariant()) {
        "PASS" { return 0 }
        "WARN" { return 1 }
        "FAIL" { return 2 }
        default { return -1 }
    }
}

function Get-PbiGovernanceConfigurationPath {
    $modulesRoot = Split-Path -Parent $PSScriptRoot
    $installerRoot = Split-Path -Parent $modulesRoot
    $platformRoot = Split-Path -Parent $installerRoot
    return (Join-Path $platformRoot "config/modularity-governance.json")
}

function Get-PbiGovernanceConfiguration {
    $configPath = Get-PbiGovernanceConfigurationPath

    if (-not (Test-Path $configPath)) {
        return [ordered]@{
            repoHealth = [ordered]@{
                enabled = $false
                mode    = "local"
            }
            moduleImpactThresholds = [ordered]@{
                warnFilesTouched      = 20
                failFilesTouched      = 50
                warnSizeDeltaBytes    = 262144
                failSizeDeltaBytes    = 1048576
                warnSemanticObjectsAdded = 10
                failSemanticObjectsAdded = 25
                warnReportVisualCount = 8
                failReportVisualCount = 20
            }
        }
    }

    return (Read-PbiJsonFile -Path $configPath)
}

function Get-PbiModuleImpactMetrics {
    param(
        [Parameter(Mandatory = $true)][string[]]$FilesTouched,
        [Parameter(Mandatory = $true)]$SemanticObjectsAdded,
        [Parameter(Mandatory = $true)]$ReportObjectsAdded,
        [Parameter(Mandatory = $true)][long]$SizeDeltaBytes
    )

    return [ordered]@{
        fileCount            = [int]@($FilesTouched).Count
        sizeDeltaBytes       = [int64]$SizeDeltaBytes
        semanticTableCount   = [int]@($SemanticObjectsAdded.tables).Count
        semanticMeasureCount = [int]@($SemanticObjectsAdded.measures).Count
        reportFileCount      = [int]@($ReportObjectsAdded.files).Count
        reportVisualCount    = [int]$ReportObjectsAdded.visualCount
    }
}

function Test-PbiModuleImpactGovernance {
    param([Parameter(Mandatory = $true)]$ImpactMetrics)

    $thresholds = (Get-PbiGovernanceConfiguration).moduleImpactThresholds
    $reasons = New-Object System.Collections.Generic.List[string]
    $status = "PASS"

    if ($ImpactMetrics.fileCount -ge [int]$thresholds.failFilesTouched) {
        $status = "FAIL"
        $reasons.Add(("filesTouched={0} exceeds fail threshold {1}." -f $ImpactMetrics.fileCount, $thresholds.failFilesTouched))
    }
    elseif (($status -ne "FAIL") -and ($ImpactMetrics.fileCount -ge [int]$thresholds.warnFilesTouched)) {
        $status = "WARN"
        $reasons.Add(("filesTouched={0} exceeds warning threshold {1}." -f $ImpactMetrics.fileCount, $thresholds.warnFilesTouched))
    }

    if ($ImpactMetrics.sizeDeltaBytes -ge [int64]$thresholds.failSizeDeltaBytes) {
        $status = "FAIL"
        $reasons.Add(("sizeDeltaBytes={0} exceeds fail threshold {1}." -f $ImpactMetrics.sizeDeltaBytes, $thresholds.failSizeDeltaBytes))
    }
    elseif (($status -ne "FAIL") -and ($ImpactMetrics.sizeDeltaBytes -ge [int64]$thresholds.warnSizeDeltaBytes)) {
        if ($status -eq "PASS") {
            $status = "WARN"
        }
        $reasons.Add(("sizeDeltaBytes={0} exceeds warning threshold {1}." -f $ImpactMetrics.sizeDeltaBytes, $thresholds.warnSizeDeltaBytes))
    }

    if ($ImpactMetrics.semanticTableCount -ge [int]$thresholds.failSemanticObjectsAdded) {
        $status = "FAIL"
        $reasons.Add(("semanticTableCount={0} exceeds fail threshold {1}." -f $ImpactMetrics.semanticTableCount, $thresholds.failSemanticObjectsAdded))
    }
    elseif (($status -ne "FAIL") -and ($ImpactMetrics.semanticTableCount -ge [int]$thresholds.warnSemanticObjectsAdded)) {
        if ($status -eq "PASS") {
            $status = "WARN"
        }
        $reasons.Add(("semanticTableCount={0} exceeds warning threshold {1}." -f $ImpactMetrics.semanticTableCount, $thresholds.warnSemanticObjectsAdded))
    }

    if ($ImpactMetrics.reportVisualCount -ge [int]$thresholds.failReportVisualCount) {
        $status = "FAIL"
        $reasons.Add(("reportVisualCount={0} exceeds fail threshold {1}." -f $ImpactMetrics.reportVisualCount, $thresholds.failReportVisualCount))
    }
    elseif (($status -ne "FAIL") -and ($ImpactMetrics.reportVisualCount -ge [int]$thresholds.warnReportVisualCount)) {
        if ($status -eq "PASS") {
            $status = "WARN"
        }
        $reasons.Add(("reportVisualCount={0} exceeds warning threshold {1}." -f $ImpactMetrics.reportVisualCount, $thresholds.warnReportVisualCount))
    }

    return [ordered]@{
        status  = $status
        reasons = @($reasons)
    }
}

function Invoke-PbiRepoHealthHook {
    param(
        [Parameter(Mandatory = $true)][string]$WorkspaceRoot,
        [Parameter(Mandatory = $true)]$Project,
        [string]$OperationId,
        [string]$OutputRoot
    )

    $governanceConfig = Get-PbiGovernanceConfiguration
    if (-not $governanceConfig.repoHealth.enabled) {
        return [ordered]@{
            enabled        = $false
            status         = "SKIPPED"
            metricsPath    = $null
            summaryPath    = $null
            failReasons    = @()
            warningReasons = @()
            errorMessage   = $null
        }
    }

    $analyzerPath = Join-Path $WorkspaceRoot "repository-health/analyzer.ps1"
    if (-not (Test-Path $analyzerPath)) {
        return [ordered]@{
            enabled        = $false
            status         = "MISSING"
            metricsPath    = $null
            summaryPath    = $null
            failReasons    = @()
            warningReasons = @()
            errorMessage   = $null
        }
    }

    $resolvedOutputRoot = if ($OutputRoot) {
        $OutputRoot
    }
    elseif ($OperationId) {
        Join-Path $Project.ModuleConfigDir ("repo-health/" + $OperationId)
    }
    else {
        Join-Path $Project.ModuleConfigDir ("repo-health/" + (Get-PbiTimestampKey))
    }

    Ensure-PbiDirectory -Path $resolvedOutputRoot

    try {
        & $analyzerPath -Mode $governanceConfig.repoHealth.mode -OutputRoot $resolvedOutputRoot -WriteHistory:$false | Out-Null
    }
    catch {
        return [ordered]@{
            enabled      = $true
            status       = "ERROR"
            metricsPath  = $null
            summaryPath  = $null
            failReasons  = @()
            warningReasons = @()
            errorMessage = $_.Exception.Message
        }
    }

    $metricsPath = Join-Path $resolvedOutputRoot "current/metrics.json"
    $summaryPath = Join-Path $resolvedOutputRoot "current/summary.md"
    $status = "UNKNOWN"
    $failReasons = @()
    $warningReasons = @()
    if (Test-Path $metricsPath) {
        $metrics = Read-PbiJsonFile -Path $metricsPath
        if ($metrics.policy -and $metrics.policy.status) {
            $status = [string]$metrics.policy.status
        }

        if ($metrics.policy -and $metrics.policy.fail_reasons) {
            $failReasons = @($metrics.policy.fail_reasons)
        }

        if ($metrics.policy -and $metrics.policy.warning_reasons) {
            $warningReasons = @($metrics.policy.warning_reasons)
        }
    }

    return [ordered]@{
        enabled        = $true
        status         = $status
        metricsPath    = $metricsPath
        summaryPath    = $summaryPath
        failReasons    = $failReasons
        warningReasons = $warningReasons
        errorMessage   = $null
    }
}

Export-ModuleMember -Function Get-PbiGovernanceConfigurationPath, Get-PbiGovernanceConfiguration, Get-PbiGovernanceStatusRank, Get-PbiModuleImpactMetrics, Test-PbiModuleImpactGovernance, Invoke-PbiRepoHealthHook
