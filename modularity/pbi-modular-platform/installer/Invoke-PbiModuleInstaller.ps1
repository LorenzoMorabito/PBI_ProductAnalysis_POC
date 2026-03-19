[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("list-modules", "validate-project", "install-module", "upgrade-module", "diff-module", "rollback-module", "set-data-source-path", "suggest-bindings", "list-binding-profiles")]
    [string]$Command,

    [string]$WorkspaceRoot,
    [string]$ProjectPath,
    [string]$Domain,
    [string]$ModuleId,
    [string]$MappingFile,
    [string]$BindingProfileId,
    [string]$SaveBindingProfileAs,
    [string]$DataSourcePath,
    [string]$SnapshotId,
    [switch]$Interactive,
    [switch]$InteractiveUi,
    [switch]$AcceptSuggested,
    [switch]$ActivateInstalledPage,
    [switch]$Force,
    [switch]$FailOnGovernanceBreach
)

$modulePaths = @(
    "Modules/Core/Pbi.Runtime.psm1",
    "Modules/Common/Pbi.Logging.psm1",
    "Modules/Core/Pbi.Schema.psm1",
    "Modules/Core/Pbi.Catalog.psm1",
    "Modules/Core/Pbi.Project.psm1",
    "Modules/Core/Pbi.Binding.psm1",
    "Modules/Core/Pbi.ModuleRendering.psm1",
    "Modules/Core/Pbi.SemanticModel.psm1",
    "Modules/Core/Pbi.Report.psm1",
    "Modules/Domains/Finance/Pbi.Finance.psm1",
    "Modules/Domains/Marketing/Pbi.Marketing.psm1",
    "Modules/Services/Pbi.ModuleInstaller.psm1",
    "Modules/Services/Pbi.Governance.psm1",
    "Modules/Services/Pbi.ModuleLifecycle.psm1"
)

foreach ($relativeModulePath in $modulePaths) {
    $modulePath = Join-Path $PSScriptRoot $relativeModulePath
    Import-Module $modulePath -Force -DisableNameChecking
}

switch ($Command) {
    "list-modules" {
        $modules = Get-PbiModuleList -WorkspaceRoot $WorkspaceRoot -Domain $Domain -ModuleId $ModuleId

        if (-not $modules) {
            Write-PbiWarning "No modules found in the discovered catalogs."
            break
        }

        $modules |
            Select-Object Domain, ModuleId, DisplayName, Version, Type, Classification, SemanticImpact, Status, PackageRoot |
            Format-Table -AutoSize
    }

    "validate-project" {
        if (-not $ProjectPath) {
            throw "ProjectPath is required for validate-project."
        }

        $results = Invoke-PbiProjectValidation `
            -WorkspaceRoot $WorkspaceRoot `
            -ProjectPath $ProjectPath `
            -Domain $Domain `
            -ModuleId $ModuleId `
            -MappingFile $MappingFile `
            -BindingProfileId $BindingProfileId `
            -SaveBindingProfileAs $SaveBindingProfileAs `
            -Interactive:$Interactive `
            -InteractiveUi:$InteractiveUi `
            -AcceptSuggested:$AcceptSuggested

        $results |
            Select-Object Domain, ModuleId, Installed, IsValid, MissingMeasures, MissingColumns, BindingMode, BindingProfileId |
            Format-Table -AutoSize
    }

    "install-module" {
        if (-not $ProjectPath) {
            throw "ProjectPath is required for install-module."
        }

        if (-not $ModuleId) {
            throw "ModuleId is required for install-module."
        }

        $result = Invoke-PbiModuleInstallOperation `
            -WorkspaceRoot $WorkspaceRoot `
            -ProjectPath $ProjectPath `
            -Domain $Domain `
            -ModuleId $ModuleId `
            -MappingFile $MappingFile `
            -BindingProfileId $BindingProfileId `
            -SaveBindingProfileAs $SaveBindingProfileAs `
            -Interactive:$Interactive `
            -InteractiveUi:$InteractiveUi `
            -AcceptSuggested:$AcceptSuggested `
            -ActivateInstalledPage:$ActivateInstalledPage `
            -Force:$Force `
            -FailOnGovernanceBreach:$FailOnGovernanceBreach

        if ($result.NoOp) {
            Write-PbiInfo ("Module {0} already aligned in project {1}" -f $result.Module.ModuleId, $result.Project.ProjectId)
        }
        else {
            Write-PbiSuccess ("Installed module {0} {1} into project {2}" -f $result.Module.ModuleId, $result.Module.Version, $result.Project.ProjectId)
            Write-Host ("  Snapshot: {0}" -f $result.SnapshotId)
            Write-Host ("  Governance: {0}" -f $result.Governance.status)
            Write-Host ("  Metadata: {0}" -f $result.Project.StateFilePath)
            Write-Host ("  Log: {0}" -f $result.LogPath)
        }
    }
    "upgrade-module" {
        if (-not $ProjectPath) {
            throw "ProjectPath is required for upgrade-module."
        }

        if (-not $ModuleId) {
            throw "ModuleId is required for upgrade-module."
        }

        $result = Upgrade-PbiModulePackage `
            -WorkspaceRoot $WorkspaceRoot `
            -ProjectPath $ProjectPath `
            -Domain $Domain `
            -ModuleId $ModuleId `
            -MappingFile $MappingFile `
            -BindingProfileId $BindingProfileId `
            -SaveBindingProfileAs $SaveBindingProfileAs `
            -Interactive:$Interactive `
            -InteractiveUi:$InteractiveUi `
            -AcceptSuggested:$AcceptSuggested `
            -ActivateInstalledPage:$ActivateInstalledPage `
            -Force:$Force `
            -FailOnGovernanceBreach:$FailOnGovernanceBreach

        if ($result.NoOp) {
            Write-PbiInfo ("Module {0} already on latest version in project {1}" -f $result.Module.ModuleId, $result.Project.ProjectId)
        }
        else {
            Write-PbiSuccess ("Upgraded module {0} to {1} in project {2}" -f $result.Module.ModuleId, $result.Module.Version, $result.Project.ProjectId)
            Write-Host ("  Snapshot: {0}" -f $result.SnapshotId)
            Write-Host ("  Diff JSON: {0}" -f $result.DiffJsonPath)
            Write-Host ("  Diff Markdown: {0}" -f $result.DiffMarkdownPath)
            Write-Host ("  Governance: {0}" -f $result.Governance.status)
            Write-Host ("  Log: {0}" -f $result.LogPath)
        }
    }
    "diff-module" {
        if (-not $ProjectPath) {
            throw "ProjectPath is required for diff-module."
        }

        if (-not $ModuleId) {
            throw "ModuleId is required for diff-module."
        }

        $result = New-PbiModuleDiffReport `
            -WorkspaceRoot $WorkspaceRoot `
            -ProjectPath $ProjectPath `
            -Domain $Domain `
            -ModuleId $ModuleId

        Write-PbiSuccess ("Generated diff for module {0} in project {1}" -f $result.Module.ModuleId, $result.Project.ProjectId)
        Write-Host ("  Diff JSON: {0}" -f $result.DiffJsonPath)
        Write-Host ("  Diff Markdown: {0}" -f $result.DiffMarkdownPath)
    }
    "rollback-module" {
        if (-not $ProjectPath) {
            throw "ProjectPath is required for rollback-module."
        }

        if (-not $ModuleId) {
            throw "ModuleId is required for rollback-module."
        }

        $result = Rollback-PbiModulePackage `
            -ProjectPath $ProjectPath `
            -ModuleId $ModuleId `
            -SnapshotId $SnapshotId

        Write-PbiSuccess ("Rolled back module {0} in project {1}" -f $result.ModuleId, $result.Project.ProjectId)
        Write-Host ("  Snapshot: {0}" -f $result.SnapshotId)
        Write-Host ("  Log: {0}" -f $result.LogPath)
    }
    "suggest-bindings" {
        if (-not $ProjectPath) {
            throw "ProjectPath is required for suggest-bindings."
        }

        if (-not $ModuleId) {
            throw "ModuleId is required for suggest-bindings."
        }

        $result = Get-PbiModuleBindingSuggestionReport `
            -WorkspaceRoot $WorkspaceRoot `
            -ProjectPath $ProjectPath `
            -Domain $Domain `
            -ModuleId $ModuleId `
            -MappingFile $MappingFile `
            -BindingProfileId $BindingProfileId `
            -SaveBindingProfileAs $SaveBindingProfileAs `
            -Interactive:$Interactive `
            -InteractiveUi:$InteractiveUi `
            -AcceptSuggested:$AcceptSuggested

        $result.Roles |
            Select-Object Kind, Label, BindingKey, Status, SelectedValue |
            Format-Table -AutoSize

        if ($result.BindingProfileId) {
            Write-Host ("  Saved binding profile: {0}" -f $result.BindingProfileId)
        }
    }
    "list-binding-profiles" {
        if (-not $ProjectPath) {
            throw "ProjectPath is required for list-binding-profiles."
        }

        $project = Resolve-PbiConsumerProject -ProjectPath $ProjectPath
        $profiles = Get-PbiProjectBindingProfiles -Project $project -ModuleId $ModuleId

        if (-not $profiles) {
            Write-PbiWarning "No binding profiles found for the selected project."
            break
        }

        $profiles |
            Select-Object ModuleId, ProfileId, BindingMode, SavedAt, RelativePath |
            Format-Table -AutoSize
    }
    "set-data-source-path" {
        if (-not $ProjectPath) {
            throw "ProjectPath is required for set-data-source-path."
        }

        if (-not $DataSourcePath) {
            throw "DataSourcePath is required for set-data-source-path."
        }

        $project = Resolve-PbiConsumerProject -ProjectPath $ProjectPath
        $resolvedDataPath = Set-PbiRootPathParameterValue -Project $project -DataSourcePath $DataSourcePath
        Write-PbiSuccess ("Configured root_path for project {0}" -f $project.ProjectId)
        Write-Host ("  Data source path: {0}" -f $resolvedDataPath)
    }
}
