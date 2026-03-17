[CmdletBinding()]
param(
    [ValidateSet("local", "pr", "push", "schedule")]
    [string]$Mode = "local",
    [string]$ConfigPath,
    [string]$OutputRoot,
    [switch]$FailOnThresholdBreach,
    [switch]$EnableGitSizer
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptRoot
. (Join-Path $scriptRoot "scripts/RepoHealth.Common.ps1")

if (-not $ConfigPath) {
    $ConfigPath = Join-Path $scriptRoot "config.json"
}

if (-not $OutputRoot) {
    $OutputRoot = Join-Path $scriptRoot "outputs"
}

$config = Get-RepoHealthConfig -Path $ConfigPath
$currentOutputDir = Join-Path $OutputRoot "current"
$historyOutputDir = Join-Path $OutputRoot "history"
Ensure-RepoHealthDirectory -Path $currentOutputDir
Ensure-RepoHealthDirectory -Path $historyOutputDir

$latestMetricsPath = Join-Path $historyOutputDir $config.latest_metrics_name
$historyCsvPath = Join-Path $historyOutputDir $config.history_csv_name
$metricsJsonPath = Join-Path $currentOutputDir "metrics.json"
$summaryPath = Join-Path $currentOutputDir "summary.md"
$gitSizerOutputPath = Join-Path $currentOutputDir $config.git_sizer_output_name

$previousMetrics = Read-RepoHealthPreviousMetrics -LatestMetricsPath $latestMetricsPath
$gitCoreMetrics = Get-RepoHealthGitCoreMetrics -RepoRoot $repoRoot
$repoMetrics = Get-RepoHealthRepositoryMetrics -RepoRoot $repoRoot -Config $config
$blobHistoryMetrics = Get-RepoHealthBlobHistoryMetrics -RepoRoot $repoRoot -Config $config

$metrics = [ordered]@{
    timestamp = (Get-Date).ToString("s")
    mode      = $Mode
    branch    = Get-RepoHealthBranchName -RepoRoot $repoRoot
    commit    = Get-RepoHealthCommitSha -RepoRoot $repoRoot
    git_core  = [ordered]@{
        size_pack_mb       = $gitCoreMetrics.SizePackMb
        object_count       = $gitCoreMetrics.ObjectCount
        packed_object_count = $gitCoreMetrics.PackedObjectCount
        pack_count         = $gitCoreMetrics.PackCount
        loose_object_count = $gitCoreMetrics.LooseObjectCount
    }
    repo = [ordered]@{
        git_size_mb           = $repoMetrics.GitSizeMb
        tracked_file_count    = $repoMetrics.TrackedFileCount
        working_file_count    = $repoMetrics.WorkingFileCount
        commit_count          = $repoMetrics.CommitCount
        largest_current_file_mb = $repoMetrics.LargestCurrentFileMb
        top_current_files     = @($repoMetrics.TopCurrentFiles)
        forbidden_files       = @($repoMetrics.ForbiddenFiles)
        tracked_excluded_files = @($repoMetrics.TrackedExcludedFiles)
    }
    history = [ordered]@{
        max_blob_mb   = $blobHistoryMetrics.MaxBlobMb
        max_blob_path = $blobHistoryMetrics.MaxBlobPath
        blob_over_1mb = $blobHistoryMetrics.BlobOver1Mb
        blob_over_5mb = $blobHistoryMetrics.BlobOver5Mb
        blob_over_max = $blobHistoryMetrics.BlobOverConfiguredMb
        largest_blobs = @($blobHistoryMetrics.LargestBlobs)
    }
}

$metrics["growth"] = Get-RepoHealthGrowthMetrics -CurrentMetrics $metrics -PreviousMetrics $previousMetrics
$metrics["policy"] = Get-RepoHealthPolicy -Metrics $metrics -Config $config

if ($EnableGitSizer) {
    try {
        $metrics["git_sizer"] = Invoke-RepoHealthGitSizer -RepoRoot $repoRoot -OutputPath $gitSizerOutputPath
    }
    catch {
        $metrics["git_sizer"] = [PSCustomObject]@{
            available   = $false
            output_path = $gitSizerOutputPath
            error       = $_.Exception.Message
        }
    }
}

Write-RepoHealthJsonFile -Path $metricsJsonPath -InputObject $metrics
Update-RepoHealthHistory -Metrics $metrics -HistoryCsvPath $historyCsvPath -LatestMetricsPath $latestMetricsPath
$summaryMarkdown = Get-RepoHealthSummaryMarkdown -Metrics $metrics
Write-RepoHealthSummaryFile -Path $summaryPath -Content $summaryMarkdown

Write-Host "Repository Health Check"
Write-Host ("  Status: {0}" -f $metrics.policy.status)
Write-Host ("  Branch: {0}" -f $metrics.branch)
Write-Host ("  Commit: {0}" -f $metrics.commit)
Write-Host ("  Size pack: {0} MB" -f $metrics.git_core.size_pack_mb)
Write-Host ("  Objects total: {0}" -f $metrics.git_core.object_count)
Write-Host ("  Pack count: {0}" -f $metrics.git_core.pack_count)
Write-Host ("  .git size: {0} MB" -f $metrics.repo.git_size_mb)
Write-Host ("  Tracked files: {0}" -f $metrics.repo.tracked_file_count)
Write-Host ("  Commits: {0}" -f $metrics.repo.commit_count)
Write-Host ("  Largest blob: {0} MB" -f $metrics.history.max_blob_mb)
Write-Host ("  Blob > 1 MB: {0}" -f $metrics.history.blob_over_1mb)
Write-Host ("  Blob > 5 MB: {0}" -f $metrics.history.blob_over_5mb)
Write-Host ("  Forbidden files: {0}" -f @($metrics.repo.forbidden_files).Count)

if (@($metrics.policy.fail_reasons).Count -gt 0) {
    Write-Host ""
    Write-Host "Blocking findings:"
    foreach ($reason in @($metrics.policy.fail_reasons)) {
        Write-Host ("  - {0}" -f $reason)
    }
}

if (@($metrics.policy.warning_reasons).Count -gt 0) {
    Write-Host ""
    Write-Host "Warnings:"
    foreach ($reason in @($metrics.policy.warning_reasons)) {
        Write-Host ("  - {0}" -f $reason)
    }
}

Write-Host ""
Write-Host ("JSON output: {0}" -f $metricsJsonPath)
Write-Host ("Summary: {0}" -f $summaryPath)
Write-Host ("History CSV: {0}" -f $historyCsvPath)

if ($env:GITHUB_OUTPUT) {
    Add-Content -Path $env:GITHUB_OUTPUT -Value ("status={0}" -f $metrics.policy.status)
    Add-Content -Path $env:GITHUB_OUTPUT -Value ("metrics_json={0}" -f $metricsJsonPath)
    Add-Content -Path $env:GITHUB_OUTPUT -Value ("summary_path={0}" -f $summaryPath)
}

if ($FailOnThresholdBreach -and $metrics.policy.status -eq "FAIL") {
    exit 1
}
