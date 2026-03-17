function Resolve-PbiConsumerProject {
    param([Parameter(Mandatory = $true)][string]$ProjectPath)

    $resolvedProjectPath = (Resolve-Path $ProjectPath).Path
    $projectItem = Get-Item $resolvedProjectPath

    if ($projectItem.PSIsContainer) {
        $pbipFiles = @(Get-ChildItem -Path $projectItem.FullName -Filter "*.pbip")

        if ($pbipFiles.Count -ne 1) {
            throw "Project folder '$resolvedProjectPath' must contain exactly one .pbip file."
        }

        $pbipPath = $pbipFiles[0].FullName
    }
    elseif ($projectItem.Extension -eq ".pbip") {
        $pbipPath = $projectItem.FullName
    }
    else {
        throw "ProjectPath must be a .pbip file or a folder containing a single .pbip file."
    }

    $projectRoot = Split-Path $pbipPath -Parent
    $pbip = Read-PbiJsonFile -Path $pbipPath
    $reportArtifact = $pbip.artifacts | Where-Object { $_.report } | Select-Object -First 1

    if (-not $reportArtifact) {
        throw "PBIP '$pbipPath' does not contain a report artifact."
    }

    $reportPath = Resolve-PbiPath -BasePath $projectRoot -RelativePath $reportArtifact.report.path
    $pbirPath = Join-Path $reportPath "definition.pbir"
    $pbir = Read-PbiJsonFile -Path $pbirPath

    if (-not $pbir.datasetReference.byPath.path) {
        throw "PBIR '$pbirPath' does not contain a datasetReference.byPath.path."
    }

    $semanticModelPath = Resolve-PbiPath -BasePath $reportPath -RelativePath $pbir.datasetReference.byPath.path
    $projectId = [System.IO.Path]::GetFileNameWithoutExtension($pbipPath)
    $moduleConfigDir = Join-Path $projectRoot ("module-config\" + $projectId)
    $stateFilePath = Join-Path $moduleConfigDir "installed-modules.json"

    return [PSCustomObject]@{
        ProjectId          = $projectId
        ProjectRoot        = $projectRoot
        PbipPath           = $pbipPath
        ReportPath         = $reportPath
        SemanticModelPath  = $semanticModelPath
        ModuleConfigDir    = $moduleConfigDir
        StateFilePath      = $stateFilePath
    }
}

function Get-PbiInstalledModulesState {
    param([Parameter(Mandatory = $true)]$Project)

    if (-not (Test-Path $Project.StateFilePath)) {
        return [ordered]@{
            installedModules = @()
        }
    }

    return Read-PbiJsonFile -Path $Project.StateFilePath
}

function Save-PbiInstalledModulesState {
    param(
        [Parameter(Mandatory = $true)]$Project,
        [Parameter(Mandatory = $true)]$State
    )

    Ensure-PbiDirectory -Path $Project.ModuleConfigDir
    Write-PbiJsonFile -Path $Project.StateFilePath -InputObject $State
}

function Get-PbiInstalledModuleRecord {
    param(
        [Parameter(Mandatory = $true)]$State,
        [Parameter(Mandatory = $true)][string]$ModuleId
    )

    return @($State.installedModules | Where-Object { $_.moduleId -eq $ModuleId } | Select-Object -First 1)
}

Export-ModuleMember -Function Resolve-PbiConsumerProject, Get-PbiInstalledModulesState, Save-PbiInstalledModulesState, Get-PbiInstalledModuleRecord
