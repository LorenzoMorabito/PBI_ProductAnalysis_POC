[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("list", "install", "upgrade", "diff", "rollback", "validate", "test", "new-module", "suggest-bindings", "list-binding-profiles")]
    [string]$Command,

    [string]$WorkspaceRoot,
    [string]$ProjectPath,
    [string]$Domain,
    [string]$ModuleId,
    [string]$MappingFile,
    [string]$BindingProfileId,
    [string]$SaveBindingProfileAs,
    [string]$SnapshotId,
    [string]$OutputRoot,
    [string]$DisplayName,
    [ValidateSet("report-only", "semantic")]
    [string]$Type = "semantic",
    [ValidateSet("report-only", "semantic-light", "semantic-heavy")]
    [string]$Classification,
    [switch]$IncludeReportPage,
    [switch]$ActivateInstalledPage,
    [switch]$Interactive,
    [switch]$InteractiveUi,
    [switch]$AcceptSuggested,
    [switch]$Force,
    [switch]$FailOnGovernanceBreach
)

$platformRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$installerScript = Join-Path $platformRoot "installer/Invoke-PbiModuleInstaller.ps1"
$qualityScript = Join-Path $platformRoot "testing/Invoke-PbiQualityChecks.ps1"
$generatorScript = Join-Path $platformRoot "scaffolding/New-PbiModuleTemplate.ps1"

switch ($Command) {
    "list" {
        & $installerScript -Command list-modules -WorkspaceRoot $WorkspaceRoot -Domain $Domain -ModuleId $ModuleId
    }
    "install" {
        & $installerScript -Command install-module -WorkspaceRoot $WorkspaceRoot -ProjectPath $ProjectPath -Domain $Domain -ModuleId $ModuleId -MappingFile $MappingFile -BindingProfileId $BindingProfileId -SaveBindingProfileAs $SaveBindingProfileAs -Interactive:$Interactive -InteractiveUi:$InteractiveUi -AcceptSuggested:$AcceptSuggested -ActivateInstalledPage:$ActivateInstalledPage -Force:$Force -FailOnGovernanceBreach:$FailOnGovernanceBreach
    }
    "upgrade" {
        & $installerScript -Command upgrade-module -WorkspaceRoot $WorkspaceRoot -ProjectPath $ProjectPath -Domain $Domain -ModuleId $ModuleId -MappingFile $MappingFile -BindingProfileId $BindingProfileId -SaveBindingProfileAs $SaveBindingProfileAs -Interactive:$Interactive -InteractiveUi:$InteractiveUi -AcceptSuggested:$AcceptSuggested -ActivateInstalledPage:$ActivateInstalledPage -Force:$Force -FailOnGovernanceBreach:$FailOnGovernanceBreach
    }
    "diff" {
        & $installerScript -Command diff-module -WorkspaceRoot $WorkspaceRoot -ProjectPath $ProjectPath -Domain $Domain -ModuleId $ModuleId
    }
    "rollback" {
        & $installerScript -Command rollback-module -ProjectPath $ProjectPath -ModuleId $ModuleId -SnapshotId $SnapshotId
    }
    "validate" {
        & $installerScript -Command validate-project -WorkspaceRoot $WorkspaceRoot -ProjectPath $ProjectPath -Domain $Domain -ModuleId $ModuleId -MappingFile $MappingFile -BindingProfileId $BindingProfileId -SaveBindingProfileAs $SaveBindingProfileAs -Interactive:$Interactive -InteractiveUi:$InteractiveUi -AcceptSuggested:$AcceptSuggested
    }
    "suggest-bindings" {
        & $installerScript -Command suggest-bindings -WorkspaceRoot $WorkspaceRoot -ProjectPath $ProjectPath -Domain $Domain -ModuleId $ModuleId -MappingFile $MappingFile -BindingProfileId $BindingProfileId -SaveBindingProfileAs $SaveBindingProfileAs -Interactive:$Interactive -InteractiveUi:$InteractiveUi -AcceptSuggested:$AcceptSuggested
    }
    "list-binding-profiles" {
        & $installerScript -Command list-binding-profiles -WorkspaceRoot $WorkspaceRoot -ProjectPath $ProjectPath -Domain $Domain -ModuleId $ModuleId
    }
    "test" {
        if ($ProjectPath) {
            & $qualityScript -Command test-project -WorkspaceRoot $WorkspaceRoot -ProjectPath $ProjectPath
        }
        elseif ($ModuleId) {
            & $qualityScript -Command test-module -WorkspaceRoot $WorkspaceRoot -Domain $Domain -ModuleId $ModuleId
        }
        else {
            & $qualityScript -Command test-repo -WorkspaceRoot $WorkspaceRoot -Domain $Domain
        }
    }
    "new-module" {
        & $generatorScript -WorkspaceRoot $WorkspaceRoot -Domain $Domain -ModuleId $ModuleId -DisplayName $DisplayName -Type $Type -Classification $Classification -OutputRoot $OutputRoot -IncludeReportPage:$IncludeReportPage -Force:$Force
    }
}
