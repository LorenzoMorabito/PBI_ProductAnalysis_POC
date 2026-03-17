param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("list-rules", "test-module", "test-project", "test-repo", "smoke-install")]
    [string]$Command,
    [string]$WorkspaceRoot,
    [string]$ProjectPath,
    [string]$Domain,
    [string]$ModuleId,
    [string]$TempRoot,
    [switch]$KeepTempCopy,
    [switch]$FailOnError
)

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$platformRoot = Split-Path -Parent $scriptRoot
$runtimeModulePath = Join-Path $platformRoot "installer/Modules/Core/Pbi.Runtime.psm1"
Import-Module $runtimeModulePath -Force -DisableNameChecking
$workspaceRoot = Get-PbiInstallerWorkspaceRoot -WorkspaceRoot $WorkspaceRoot -ScriptRoot $platformRoot

$installerModulePaths = @(
    (Join-Path $platformRoot "installer/Modules/Common/Pbi.Logging.psm1"),
    $runtimeModulePath,
    (Join-Path $platformRoot "installer/Modules/Core/Pbi.Catalog.psm1"),
    (Join-Path $platformRoot "installer/Modules/Core/Pbi.Project.psm1"),
    (Join-Path $platformRoot "installer/Modules/Core/Pbi.SemanticModel.psm1"),
    (Join-Path $platformRoot "installer/Modules/Core/Pbi.Report.psm1"),
    (Join-Path $platformRoot "installer/Modules/Domains/Finance/Pbi.Finance.psm1"),
    (Join-Path $platformRoot "installer/Modules/Domains/Marketing/Pbi.Marketing.psm1"),
    (Join-Path $platformRoot "installer/Modules/Services/Pbi.ModuleInstaller.psm1")
)

$testingModulePaths = @(
    (Join-Path $scriptRoot "Modules/Common/Pbi.TestResults.psm1"),
    (Join-Path $scriptRoot "Modules/Core/Pbi.TestDiscovery.psm1"),
    (Join-Path $scriptRoot "Modules/Rules/Pbi.ManifestRules.psm1"),
    (Join-Path $scriptRoot "Modules/Rules/Pbi.SemanticRules.psm1"),
    (Join-Path $scriptRoot "Modules/Rules/Pbi.ReportRules.psm1"),
    (Join-Path $scriptRoot "Modules/Services/Pbi.QualityChecks.psm1")
)

foreach ($modulePath in @($installerModulePaths + $testingModulePaths)) {
    Import-Module $modulePath -Force -DisableNameChecking
}

function Show-PbiQualityResults {
    param([Parameter(Mandatory = $true)]$Outcome)

    $counts = $Outcome.Counts
    Write-PbiInfo ("Quality check summary: Errors={0} Warnings={1} Infos={2} Total={3}" -f $counts.Errors, $counts.Warnings, $counts.Infos, $counts.Total)

    if (@($Outcome.Results).Count -gt 0) {
        $Outcome.Results |
            Sort-Object Severity, Scope, Target, RuleId |
            Select-Object Severity, Scope, Target, RuleId, Message, Path |
            Format-Table -AutoSize
    }
    else {
        Write-PbiSuccess "No findings."
    }
}

switch ($Command) {
    "list-rules" {
        Get-PbiQualityRuleCatalog | Format-Table -AutoSize
        exit 0
    }
    "test-module" {
        $outcome = Invoke-PbiModuleQualityChecks -WorkspaceRoot $workspaceRoot -Domain $Domain -ModuleId $ModuleId
    }
    "test-project" {
        if (-not $ProjectPath) {
            throw "ProjectPath is required for test-project."
        }

        $outcome = Invoke-PbiProjectQualityChecks -ProjectPath $ProjectPath
    }
    "test-repo" {
        $outcome = Invoke-PbiRepoQualityChecks -WorkspaceRoot $workspaceRoot -Domain $Domain -ModuleId $ModuleId
    }
    "smoke-install" {
        if (-not $ProjectPath) {
            throw "ProjectPath is required for smoke-install."
        }

        if (-not $ModuleId) {
            throw "ModuleId is required for smoke-install."
        }

        $outcome = Invoke-PbiSmokeInstallCheck -WorkspaceRoot $workspaceRoot -ProjectPath $ProjectPath -Domain $Domain -ModuleId $ModuleId -TempRoot $TempRoot -KeepTempCopy:$KeepTempCopy
    }
}

Show-PbiQualityResults -Outcome $outcome

if ($FailOnError -and (Test-PbiQualityHasErrors -Results @($outcome.Results))) {
    exit 1
}
