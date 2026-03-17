[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("list-modules", "validate-project", "install-module")]
    [string]$Command,

    [string]$WorkspaceRoot,
    [string]$ProjectPath,
    [string]$Domain,
    [string]$ModuleId,
    [string]$MappingFile,
    [switch]$ActivateInstalledPage,
    [switch]$Force
)

$modulePaths = @(
    "Modules/Common/Pbi.Logging.psm1",
    "Modules/Core/Pbi.Runtime.psm1",
    "Modules/Core/Pbi.Catalog.psm1",
    "Modules/Core/Pbi.Project.psm1",
    "Modules/Core/Pbi.SemanticModel.psm1",
    "Modules/Core/Pbi.Report.psm1",
    "Modules/Domains/Finance/Pbi.Finance.psm1",
    "Modules/Services/Pbi.ModuleInstaller.psm1"
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
            Select-Object Domain, ModuleId, DisplayName, Version, Status, PackageRoot |
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
            -MappingFile $MappingFile

        $results |
            Select-Object Domain, ModuleId, Installed, IsValid, MissingMeasures, MissingColumns |
            Format-Table -AutoSize
    }

    "install-module" {
        if (-not $ProjectPath) {
            throw "ProjectPath is required for install-module."
        }

        if (-not $ModuleId) {
            throw "ModuleId is required for install-module."
        }

        $result = Install-PbiModulePackage `
            -WorkspaceRoot $WorkspaceRoot `
            -ProjectPath $ProjectPath `
            -Domain $Domain `
            -ModuleId $ModuleId `
            -MappingFile $MappingFile `
            -ActivateInstalledPage:$ActivateInstalledPage `
            -Force:$Force

        Write-PbiSuccess ("Installed module {0} {1} into project {2}" -f $result.ModuleId, $result.Version, $result.ProjectId)
        Write-Host ("  Semantic tables: {0}" -f (($result.SemanticTables | Sort-Object) -join ", "))

        if ($result.ReportPageName) {
            Write-Host ("  Report page: {0}" -f $result.ReportPageName)
        }

        Write-Host ("  Metadata: {0}" -f $result.StateFilePath)
    }
}
