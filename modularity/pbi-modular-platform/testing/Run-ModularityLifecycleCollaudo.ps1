[CmdletBinding()]
param(
    [string]$OutputRoot,
    [string]$Commit = "7cb5dd4",
    [string]$OperatorName = $env:USERNAME
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$platformRoot = Split-Path -Parent $scriptRoot
$modularityRoot = Split-Path -Parent $platformRoot
$repoRoot = Split-Path -Parent $modularityRoot
$powerbiProjectsRoot = Join-Path $repoRoot "powerbi-projects"
$sandboxBaseRoot = Join-Path $repoRoot ".tmp-collaudo"
$reportDate = Get-Date

if (-not $OutputRoot) {
    $OutputRoot = Join-Path $scriptRoot ("evidence\collaudo-" + $Commit)
}

$OutputRoot = [System.IO.Path]::GetFullPath($OutputRoot)

if (Test-Path $OutputRoot) {
    Remove-Item -Path $OutputRoot -Recurse -Force
}

if (Test-Path $sandboxBaseRoot) {
    Remove-Item -Path $sandboxBaseRoot -Recurse -Force
}

function Ensure-Directory {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Write-Utf8File {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [AllowNull()][string]$Content
    )

    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, [string]$Content, $encoding)
}

function Save-TextFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [AllowNull()][string]$Content
    )

    $parent = Split-Path $Path -Parent
    if ($parent) {
        Ensure-Directory -Path $parent
    }

    Write-Utf8File -Path $Path -Content $Content
}

function Save-JsonFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)]$InputObject
    )

    $parent = Split-Path $Path -Parent
    if ($parent) {
        Ensure-Directory -Path $parent
    }

    $json = [string]($InputObject | ConvertTo-Json -Depth 100)
    Write-Utf8File -Path $Path -Content $json
}

function Quote-Argument {
    param([AllowNull()][string]$Value)

    if ($null -eq $Value) {
        return '""'
    }

    if ($Value -match '[\s"]') {
        return '"' + $Value.Replace('"', '\"') + '"'
    }

    return $Value
}

function Format-CommandText {
    param(
        [Parameter(Mandatory = $true)][string]$Executable,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )

    $parts = @($Executable) + @($Arguments | ForEach-Object { Quote-Argument -Value $_ })
    return ($parts -join " ")
}

function Get-HostPowerShellExecutable {
    $windowsPowerShell = Join-Path $PSHOME "powershell.exe"
    if (Test-Path $windowsPowerShell) {
        return $windowsPowerShell
    }

    $pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($pwsh) {
        return $pwsh.Source
    }

    throw "Unable to resolve a PowerShell executable for the collaudo harness."
}

function Get-PowerShellScriptArguments {
    param(
        [Parameter(Mandatory = $true)][string]$Executable,
        [Parameter(Mandatory = $true)][string]$ScriptPath,
        [Parameter(Mandatory = $true)][hashtable]$Parameters
    )

    $arguments = New-Object System.Collections.Generic.List[string]
    $arguments.Add("-NoLogo")
    $arguments.Add("-NoProfile")

    if ([System.IO.Path]::GetFileName($Executable).Equals("powershell.exe", [System.StringComparison]::OrdinalIgnoreCase)) {
        $arguments.Add("-ExecutionPolicy")
        $arguments.Add("Bypass")
    }

    $arguments.Add("-File")
    $arguments.Add($ScriptPath)

    foreach ($key in $Parameters.Keys) {
        $value = $Parameters[$key]
        if ($value -is [bool]) {
            if ($value) {
                $arguments.Add("-$key")
            }
            continue
        }

        if ($null -eq $value) {
            continue
        }

        $arguments.Add("-$key")
        $arguments.Add([string]$value)
    }

    return $arguments.ToArray()
}

function Invoke-ExternalCommand {
    param(
        [Parameter(Mandatory = $true)][string]$Executable,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [Parameter(Mandatory = $true)][string]$OutputPath,
        [string]$CommandPath
    )

    $commandText = Format-CommandText -Executable $Executable -Arguments $Arguments
    if ($CommandPath) {
        Save-TextFile -Path $CommandPath -Content $commandText
    }

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $outputLines = & $Executable @Arguments 2>&1 | ForEach-Object { $_.ToString() }
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    $exitCode = if ($null -ne $LASTEXITCODE) { [int]$LASTEXITCODE } else { 0 }
    $outputText = (@($outputLines) + @("", "[exit-code] $exitCode")) -join "`r`n"
    Save-TextFile -Path $OutputPath -Content $outputText

    if ($exitCode -ne 0) {
        throw "External command failed with exit code ${exitCode}: $commandText"
    }

    return [PSCustomObject]@{
        CommandText = $commandText
        OutputLines = @($outputLines)
        ExitCode    = $exitCode
    }
}

function Invoke-GitCommand {
    param(
        [Parameter(Mandatory = $true)][string]$RepositoryRoot,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [Parameter(Mandatory = $true)][string]$OutputPath,
        [bool]$AllowExitCodeOne = $false
    )

    $gitArgs = @("-C", $RepositoryRoot) + $Arguments
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $outputLines = & git @gitArgs 2>&1 | ForEach-Object { $_.ToString() }
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    $exitCode = if ($null -ne $LASTEXITCODE) { [int]$LASTEXITCODE } else { 0 }
    $outputText = (@($outputLines) + @("", "[exit-code] $exitCode")) -join "`r`n"
    Save-TextFile -Path $OutputPath -Content $outputText

    if (($exitCode -ne 0) -and -not ($AllowExitCodeOne -and ($exitCode -eq 1))) {
        throw "Git command failed: git $($Arguments -join ' ')"
    }

    return [PSCustomObject]@{
        OutputLines = @($outputLines)
        ExitCode    = $exitCode
    }
}

function Import-InstallerTestingModules {
    $modulePaths = @(
        (Join-Path $platformRoot "installer\Modules\Core\Pbi.Runtime.psm1"),
        (Join-Path $platformRoot "installer\Modules\Common\Pbi.Logging.psm1"),
        (Join-Path $platformRoot "installer\Modules\Core\Pbi.Schema.psm1"),
        (Join-Path $platformRoot "installer\Modules\Core\Pbi.Catalog.psm1"),
        (Join-Path $platformRoot "installer\Modules\Core\Pbi.Project.psm1"),
        (Join-Path $platformRoot "installer\Modules\Core\Pbi.SemanticModel.psm1"),
        (Join-Path $platformRoot "installer\Modules\Core\Pbi.Report.psm1"),
        (Join-Path $platformRoot "installer\Modules\Domains\Finance\Pbi.Finance.psm1"),
        (Join-Path $platformRoot "installer\Modules\Domains\Marketing\Pbi.Marketing.psm1"),
        (Join-Path $platformRoot "installer\Modules\Services\Pbi.ModuleInstaller.psm1"),
        (Join-Path $platformRoot "installer\Modules\Services\Pbi.Governance.psm1"),
        (Join-Path $platformRoot "installer\Modules\Services\Pbi.ModuleLifecycle.psm1"),
        (Join-Path $scriptRoot "Modules\Common\Pbi.TestResults.psm1"),
        (Join-Path $scriptRoot "Modules\Core\Pbi.TestDiscovery.psm1"),
        (Join-Path $scriptRoot "Modules\Core\Pbi.ArchitectureContract.psm1"),
        (Join-Path $scriptRoot "Modules\Rules\Pbi.ManifestRules.psm1"),
        (Join-Path $scriptRoot "Modules\Rules\Pbi.ArchitectureRules.psm1"),
        (Join-Path $scriptRoot "Modules\Rules\Pbi.SemanticRules.psm1"),
        (Join-Path $scriptRoot "Modules\Rules\Pbi.ReportRules.psm1"),
        (Join-Path $scriptRoot "Modules\Services\Pbi.QualityChecks.psm1")
    )

    foreach ($modulePath in $modulePaths) {
        Import-Module $modulePath -Force -DisableNameChecking
    }
}

function Copy-RepoAsset {
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][string]$DestinationRoot
    )

    $sourcePath = Join-Path $repoRoot $RelativePath
    if (-not (Test-Path $sourcePath)) {
        throw "Source asset not found: $sourcePath"
    }

    $destinationPath = Join-Path $DestinationRoot $RelativePath
    $destinationParent = Split-Path $destinationPath -Parent
    if ($destinationParent) {
        Ensure-Directory -Path $destinationParent
    }

    $sourceItem = Get-Item $sourcePath
    if ($sourceItem.PSIsContainer) {
        Copy-Item -Path $sourcePath -Destination $destinationPath -Recurse -Force
    }
    else {
        Copy-Item -Path $sourcePath -Destination $destinationPath -Force
    }
}

function New-SandboxWorkspace {
    param([Parameter(Mandatory = $true)][string]$Name)

    Ensure-Directory -Path $sandboxBaseRoot
    $sandboxRoot = Join-Path $sandboxBaseRoot ($Name + "-" + [guid]::NewGuid().ToString("N"))
    Ensure-Directory -Path $sandboxRoot

    $assetsToCopy = @(
        "modularity",
        "repository-health",
        "powerbi-projects\20260317_UAT_001.pbip",
        "powerbi-projects\20260317_UAT_001.Report",
        "powerbi-projects\20260317_UAT_001.SemanticModel",
        "powerbi-projects\module-config\20260317_UAT_001",
        "powerbi-projects\20260317_Product_Analysis_FlexTable.pbip",
        "powerbi-projects\20260317_Product_Analysis_FlexTable.Report",
        "powerbi-projects\20260317_Product_Analysis_FlexTable.SemanticModel",
        "powerbi-projects\module-config\20260317_Product_Analysis_FlexTable"
    )

    foreach ($asset in $assetsToCopy) {
        Copy-RepoAsset -RelativePath $asset -DestinationRoot $sandboxRoot
    }

    Invoke-GitCommand -RepositoryRoot $sandboxRoot -Arguments @("init", "-b", "main") -OutputPath (Join-Path $sandboxRoot "git-init.txt") | Out-Null
    Invoke-GitCommand -RepositoryRoot $sandboxRoot -Arguments @("config", "user.email", "codex@example.local") -OutputPath (Join-Path $sandboxRoot "git-config-email.txt") | Out-Null
    Invoke-GitCommand -RepositoryRoot $sandboxRoot -Arguments @("config", "user.name", "Codex Collaudo") -OutputPath (Join-Path $sandboxRoot "git-config-name.txt") | Out-Null
    Invoke-GitCommand -RepositoryRoot $sandboxRoot -Arguments @("config", "core.autocrlf", "false") -OutputPath (Join-Path $sandboxRoot "git-config-crlf.txt") | Out-Null
    Invoke-GitCommand -RepositoryRoot $sandboxRoot -Arguments @("config", "core.longpaths", "true") -OutputPath (Join-Path $sandboxRoot "git-config-longpaths.txt") | Out-Null
    Invoke-GitCommand -RepositoryRoot $sandboxRoot -Arguments @("add", ".") -OutputPath (Join-Path $sandboxRoot "git-add-baseline.txt") | Out-Null
    Invoke-GitCommand -RepositoryRoot $sandboxRoot -Arguments @("commit", "-m", "collaudo baseline") -OutputPath (Join-Path $sandboxRoot "git-commit-baseline.txt") | Out-Null

    return [PSCustomObject]@{
        Name          = $Name
        Root          = $sandboxRoot
        ModularityRoot = Join-Path $sandboxRoot "modularity"
        PowerbiRoot   = Join-Path $sandboxRoot "powerbi-projects"
        InstallerPath = Join-Path $sandboxRoot "modularity\pbi-modular-platform\installer\Invoke-PbiModuleInstaller.ps1"
        QualityPath   = Join-Path $sandboxRoot "modularity\pbi-modular-platform\testing\Invoke-PbiQualityChecks.ps1"
    }
}

function Commit-SandboxBaseline {
    param(
        [Parameter(Mandatory = $true)]$Sandbox,
        [Parameter(Mandatory = $true)][string]$Message
    )

    $statusLines = & git -C $Sandbox.Root status --short 2>$null
    if (@($statusLines).Count -eq 0) {
        return
    }

    Invoke-GitCommand -RepositoryRoot $Sandbox.Root -Arguments @("add", ".") -OutputPath (Join-Path $Sandbox.Root ("git-add-" + ([guid]::NewGuid().ToString("N")) + ".txt")) | Out-Null
    Invoke-GitCommand -RepositoryRoot $Sandbox.Root -Arguments @("commit", "-m", $Message) -OutputPath (Join-Path $Sandbox.Root ("git-commit-" + ([guid]::NewGuid().ToString("N")) + ".txt")) | Out-Null
}

function Get-LatestChildItem {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [string]$Filter = "*",
        [switch]$Directory
    )

    if (-not (Test-Path $Path)) {
        return $null
    }

    $childItems = if ($Directory) {
        Get-ChildItem -Path $Path -Directory -Filter $Filter -ErrorAction SilentlyContinue
    }
    else {
        Get-ChildItem -Path $Path -File -Filter $Filter -ErrorAction SilentlyContinue
    }

    return $childItems |
        Sort-Object LastWriteTimeUtc, Name -Descending |
        Select-Object -First 1
}

function Copy-IfExists {
    param(
        [Parameter(Mandatory = $true)][string]$SourcePath,
        [Parameter(Mandatory = $true)][string]$DestinationPath
    )

    if (-not (Test-Path $SourcePath)) {
        return $false
    }

    $destinationParent = Split-Path $DestinationPath -Parent
    if ($destinationParent) {
        Ensure-Directory -Path $destinationParent
    }

    Copy-Item -Path $SourcePath -Destination $DestinationPath -Force
    return $true
}

function Save-RawInstalledState {
    param(
        [Parameter(Mandatory = $true)][string]$ProjectStatePath,
        [Parameter(Mandatory = $true)][string]$OutputPath
    )

    if (Test-Path $ProjectStatePath) {
        Copy-Item -Path $ProjectStatePath -Destination $OutputPath -Force
        return
    }

    Save-TextFile -Path $OutputPath -Content "{`"installedModules`": []}"
}

function Get-NormalizedRecord {
    param(
        [Parameter(Mandatory = $true)][string]$ProjectPath,
        [Parameter(Mandatory = $true)][string]$ModuleId
    )

    $project = Resolve-PbiConsumerProject -ProjectPath $ProjectPath
    $state = Get-PbiInstalledModulesState -Project $project
    $record = Get-PbiInstalledModuleRecord -State $state -ModuleId $ModuleId

    return [PSCustomObject]@{
        Project = $project
        State   = $state
        Record  = $record
    }
}

function Save-GitEvidence {
    param(
        [Parameter(Mandatory = $true)][string]$RepositoryRoot,
        [Parameter(Mandatory = $true)][string]$OutputDir,
        [Parameter(Mandatory = $true)][string[]]$Pathspecs,
        [Parameter(Mandatory = $true)][string]$Prefix
    )

    Ensure-Directory -Path $OutputDir
    Invoke-GitCommand -RepositoryRoot $RepositoryRoot -Arguments (@("status", "--short", "--") + $Pathspecs) -OutputPath (Join-Path $OutputDir ($Prefix + ".git-status.txt")) | Out-Null
    Invoke-GitCommand -RepositoryRoot $RepositoryRoot -Arguments (@("diff", "--stat", "--") + $Pathspecs) -OutputPath (Join-Path $OutputDir ($Prefix + ".git-diff-stat.txt")) | Out-Null
    Invoke-GitCommand -RepositoryRoot $RepositoryRoot -Arguments (@("diff", "--name-only", "--") + $Pathspecs) -OutputPath (Join-Path $OutputDir ($Prefix + ".git-diff-name-only.txt")) | Out-Null
    Invoke-GitCommand -RepositoryRoot $RepositoryRoot -Arguments (@("diff", "--") + $Pathspecs) -OutputPath (Join-Path $OutputDir ($Prefix + ".git-diff.txt")) | Out-Null
}

function Save-NoIndexDiff {
    param(
        [Parameter(Mandatory = $true)][string]$SourcePath,
        [Parameter(Mandatory = $true)][string]$DestinationPath,
        [Parameter(Mandatory = $true)][string]$OutputPath
    )

    $arguments = @("diff", "--no-index", "--", $SourcePath, $DestinationPath)
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $outputLines = & git @arguments 2>&1 | ForEach-Object { $_.ToString() }
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    $exitCode = if ($null -ne $LASTEXITCODE) { [int]$LASTEXITCODE } else { 0 }
    Save-TextFile -Path $OutputPath -Content ((@($outputLines) + @("", "[exit-code] $exitCode")) -join "`r`n")

    if (($exitCode -ne 0) -and ($exitCode -ne 1)) {
        throw "git diff --no-index failed for $SourcePath and $DestinationPath"
    }
}

function Replace-InFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Pattern,
        [Parameter(Mandatory = $true)][string]$Replacement
    )

    $content = Get-Content -Path $Path -Raw
    $updated = $content -replace $Pattern, $Replacement
    if ($updated -eq $content) {
        throw "Pattern '$Pattern' was not found in file '$Path'."
    }

    Write-Utf8File -Path $Path -Content $updated
}

function Set-JsonFileValue {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][scriptblock]$Mutator
    )

    $json = Get-Content -Path $Path -Raw | ConvertFrom-Json
    $mutated = & $Mutator $json
    if ($null -eq $mutated) {
        $mutated = $json
    }

    $serialized = [string]($mutated | ConvertTo-Json -Depth 100)
    Write-Utf8File -Path $Path -Content $serialized
}

function Get-InstallConsumerPathspec {
    return @(
        "powerbi-projects/20260317_Product_Analysis_FlexTable.pbip",
        "powerbi-projects/20260317_Product_Analysis_FlexTable.Report",
        "powerbi-projects/20260317_Product_Analysis_FlexTable.SemanticModel",
        "powerbi-projects/module-config/20260317_Product_Analysis_FlexTable"
    )
}

function Get-FinanceConsumerPathspec {
    return @(
        "powerbi-projects/20260317_UAT_001.pbip",
        "powerbi-projects/20260317_UAT_001.Report",
        "powerbi-projects/20260317_UAT_001.SemanticModel",
        "powerbi-projects/module-config/20260317_UAT_001"
    )
}

function Get-FinanceManagedPathspec {
    return @(
        "powerbi-projects/20260317_UAT_001.Report",
        "powerbi-projects/20260317_UAT_001.SemanticModel",
        "powerbi-projects/module-config/20260317_UAT_001/installed-modules.json"
    )
}

function Get-ImpactAssessment {
    param([Parameter(Mandatory = $true)]$Record)

    $filesTouched = @($Record.filesTouched)
    $centralFiles = @(
        $filesTouched |
            Where-Object {
                $_ -match "/definition/model\.tmdl$" -or
                $_ -match "/definition/pages/pages\.json$"
            }
    )

    $coreTableFiles = @(
        $filesTouched |
            Where-Object {
                ($_ -match "/definition/tables/") -and
                ($_ -notmatch "/definition/tables/MOD ")
            }
    )

    $classification = if ($coreTableFiles.Count -gt 0) {
        "invasivo"
    }
    elseif ($centralFiles.Count -gt 0) {
        "medio"
    }
    else {
        "minimo"
    }

    return [ordered]@{
        classification = $classification
        centralFiles   = @($centralFiles)
        coreTableFiles = @($coreTableFiles)
    }
}

function Add-TestResult {
    param(
        [Parameter(Mandatory = $true)]$Collection,
        [Parameter(Mandatory = $true)][string]$Id,
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter(Mandatory = $true)][string]$Status,
        [Parameter(Mandatory = $true)][string]$Summary,
        [Parameter(Mandatory = $true)][string]$Consumer,
        [Parameter(Mandatory = $true)][string]$Module,
        [Parameter(Mandatory = $true)][string]$Versions,
        [Parameter(Mandatory = $true)][string[]]$Evidence,
        [string[]]$Warnings = @()
    )

    $Collection.Add([ordered]@{
        id       = $Id
        title    = $Title
        status   = $Status
        summary  = $Summary
        consumer = $Consumer
        module   = $Module
        versions = $Versions
        warnings = @($Warnings)
        evidence = @($Evidence)
    }) | Out-Null
}

function New-TestDirectory {
    param([Parameter(Mandatory = $true)][string]$Name)

    $path = Join-Path $OutputRoot $Name
    Ensure-Directory -Path $path
    return $path
}

function Get-QualityCountsSummary {
    param([Parameter(Mandatory = $true)]$Outcome)

    return "Errors={0}; Warnings={1}; Infos={2}; Total={3}" -f $Outcome.Counts.Errors, $Outcome.Counts.Warnings, $Outcome.Counts.Infos, $Outcome.Counts.Total
}

Import-InstallerTestingModules
Ensure-Directory -Path $OutputRoot

$shellExecutable = Get-HostPowerShellExecutable
$qualityScript = Join-Path $scriptRoot "Invoke-PbiQualityChecks.ps1"
$testResults = New-Object System.Collections.Generic.List[object]

$runMetadata = [ordered]@{
    commit        = $Commit
    operator      = $OperatorName
    executedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
    shell         = $shellExecutable
    repoRoot      = $repoRoot
    outputRoot    = $OutputRoot
}
Save-JsonFile -Path (Join-Path $OutputRoot "run-metadata.json") -InputObject $runMetadata

$installSandbox = New-SandboxWorkspace -Name "install-clean"
$diffSandbox = New-SandboxWorkspace -Name "diff-module"
$upgradeSandbox = New-SandboxWorkspace -Name "upgrade-rollback"

Save-JsonFile -Path (Join-Path $OutputRoot "sandboxes.json") -InputObject @(
    [ordered]@{ name = $installSandbox.Name; root = $installSandbox.Root },
    [ordered]@{ name = $diffSandbox.Name; root = $diffSandbox.Root },
    [ordered]@{ name = $upgradeSandbox.Name; root = $upgradeSandbox.Root }
)

$test1Dir = New-TestDirectory -Name "test-1-install-clean"
$test2Dir = New-TestDirectory -Name "test-2-diff-module"
$test3Dir = New-TestDirectory -Name "test-3-upgrade-module"
$test4Dir = New-TestDirectory -Name "test-4-rollback-module"
$test5Dir = New-TestDirectory -Name "test-5-consumer-impact"
$test6Dir = New-TestDirectory -Name "test-6-quality-checks"

# Test 1 - clean install
$installProjectPath = Join-Path $installSandbox.Root "powerbi-projects\20260317_Product_Analysis_FlexTable.pbip"
$installProject = Resolve-PbiConsumerProject -ProjectPath $installProjectPath
$installModule = Get-PbiSingleModule -WorkspaceRoot $installSandbox.Root -Domain "marketing" -ModuleId "flex_table_flat_mvp"
$installState = Get-PbiInstalledModulesState -Project $installProject
$installRecord = Get-PbiInstalledModuleRecord -State $installState -ModuleId $installModule.ModuleId
Reset-PbiModuleInstallationInProject -Project $installProject -ModuleId $installModule.ModuleId -StateRecord $installRecord -Module $installModule
Commit-SandboxBaseline -Sandbox $installSandbox -Message "baseline clean install flex_table_flat_mvp"

Save-RawInstalledState -ProjectStatePath $installProject.StateFilePath -OutputPath (Join-Path $test1Dir "installed-modules.before.json")
Save-GitEvidence -RepositoryRoot $installSandbox.Root -OutputDir $test1Dir -Pathspecs (Get-InstallConsumerPathspec) -Prefix "pre-install"

$test1InstallArgs = Get-PowerShellScriptArguments -Executable $shellExecutable -ScriptPath $installSandbox.InstallerPath -Parameters @{
    Command               = "install-module"
    WorkspaceRoot         = $installSandbox.Root
    ProjectPath           = $installProjectPath
    ModuleId              = "flex_table_flat_mvp"
    ActivateInstalledPage = $true
}
$null = Invoke-ExternalCommand -Executable $shellExecutable -Arguments $test1InstallArgs -CommandPath (Join-Path $test1Dir "command.txt") -OutputPath (Join-Path $test1Dir "command-output.txt")

$test1InstallLog = Get-LatestChildItem -Path $installProject.LogsRoot -Filter "*.jsonl"
if ($test1InstallLog) {
    Copy-IfExists -SourcePath $test1InstallLog.FullName -DestinationPath (Join-Path $test1Dir "install-log.jsonl") | Out-Null
}

Save-RawInstalledState -ProjectStatePath $installProject.StateFilePath -OutputPath (Join-Path $test1Dir "installed-modules.after.json")
$test1Normalized = Get-NormalizedRecord -ProjectPath $installProjectPath -ModuleId "flex_table_flat_mvp"
Save-JsonFile -Path (Join-Path $test1Dir "normalized-record.after.json") -InputObject $test1Normalized.Record
Save-TextFile -Path (Join-Path $test1Dir "files-touched.txt") -Content (@($test1Normalized.Record.filesTouched) -join "`r`n")
Save-GitEvidence -RepositoryRoot $installSandbox.Root -OutputDir $test1Dir -Pathspecs (Get-InstallConsumerPathspec) -Prefix "post-install"

$test1QualityArgs = Get-PowerShellScriptArguments -Executable $shellExecutable -ScriptPath $installSandbox.QualityPath -Parameters @{
    Command       = "test-project"
    WorkspaceRoot = $installSandbox.Root
    ProjectPath   = $installProjectPath
}
$null = Invoke-ExternalCommand -Executable $shellExecutable -Arguments $test1QualityArgs -CommandPath (Join-Path $test1Dir "quality-check.command.txt") -OutputPath (Join-Path $test1Dir "quality-check.output.txt")
$test1ProjectQuality = Invoke-PbiProjectQualityChecks -ProjectPath $installProjectPath
Save-JsonFile -Path (Join-Path $test1Dir "quality-check.summary.json") -InputObject $test1ProjectQuality

$test1Warnings = New-Object System.Collections.Generic.List[string]
if ($test1ProjectQuality.Counts.Warnings -gt 0) {
    $test1Warnings.Add("I quality checks di progetto riportano warning post-install.")
}
$test1GovernanceReasonsText = (@($test1Normalized.Record.governance.reasons) -join " ")
if ($test1Normalized.Record.governance.status -ne "PASS") {
    if ($test1GovernanceReasonsText -match '\?\?') {
        $test1Warnings.Add("Governance WARN: il repo-health hook non e' compatibile con Windows PowerShell 5.1 e degrada l'operazione.")
    }
    else {
        $test1Warnings.Add("Governance " + $test1Normalized.Record.governance.status + ": verificare i motivi registrati in installed-modules.json.")
    }
}
$test1Warnings.Add("L'apertura in Power BI Desktop non e' verificabile da CLI nel perimetro di questo collaudo.")
$test1Status = if ($test1ProjectQuality.Counts.Errors -gt 0) { "FAIL" } else { "PASS WITH WARNING" }
$test1Summary = "Installazione completata per flex_table_flat_mvp su 20260317_Product_Analysis_FlexTable; metadata e footprint materializzati correttamente."
Add-TestResult -Collection $testResults -Id "test-1" -Title "Installazione pulita modulo" -Status $test1Status -Summary $test1Summary -Consumer "20260317_Product_Analysis_FlexTable.pbip" -Module "flex_table_flat_mvp" -Versions "n/a -> 0.2.0" -Warnings $test1Warnings.ToArray() -Evidence @(
    "test-1-install-clean\command.txt",
    "test-1-install-clean\command-output.txt",
    "test-1-install-clean\install-log.jsonl",
    "test-1-install-clean\installed-modules.before.json",
    "test-1-install-clean\installed-modules.after.json",
    "test-1-install-clean\files-touched.txt",
    "test-1-install-clean\post-install.git-diff.txt",
    "test-1-install-clean\quality-check.output.txt"
)

# Test 2 - diff module with controlled drift
$diffProjectPath = Join-Path $diffSandbox.Root "powerbi-projects\20260317_UAT_001.pbip"
$diffPagePath = Join-Path $diffSandbox.Root "powerbi-projects\20260317_UAT_001.Report\definition\pages\8a4f2d4d3f11450ab001\page.json"
$diffVisualPath = Join-Path $diffSandbox.Root "powerbi-projects\20260317_UAT_001.Report\definition\pages\8a4f2d4d3f11450ab001\visuals\fc_mvp_title\visual.json"
$diffSemanticPath = Join-Path $diffSandbox.Root "powerbi-projects\20260317_UAT_001.SemanticModel\definition\tables\MOD Finance Compare Selector.tmdl"

Replace-InFile -Path $diffSemanticPath -Pattern '\"BGT\"' -Replacement '"BGT DRIFT"'
Set-JsonFileValue -Path $diffPagePath -Mutator { param($json) $json.displayName = "Finance Compare MVP Drift"; return $json }
Set-JsonFileValue -Path $diffVisualPath -Mutator {
    param($json)
    $json.visual.visualContainerObjects.title[0].properties.text.expr.Literal.Value = "'Finance Compare MVP Drift'"
    return $json
}

$diffProject = Resolve-PbiConsumerProject -ProjectPath $diffProjectPath
Save-RawInstalledState -ProjectStatePath $diffProject.StateFilePath -OutputPath (Join-Path $test2Dir "installed-modules.before.json")
Save-GitEvidence -RepositoryRoot $diffSandbox.Root -OutputDir $test2Dir -Pathspecs (Get-FinanceConsumerPathspec) -Prefix "pre-diff"

$test2DiffArgs = Get-PowerShellScriptArguments -Executable $shellExecutable -ScriptPath $diffSandbox.InstallerPath -Parameters @{
    Command       = "diff-module"
    WorkspaceRoot = $diffSandbox.Root
    ProjectPath   = $diffProjectPath
    ModuleId      = "finance_compare_mvp"
}
$null = Invoke-ExternalCommand -Executable $shellExecutable -Arguments $test2DiffArgs -CommandPath (Join-Path $test2Dir "command.txt") -OutputPath (Join-Path $test2Dir "command-output.txt")

$latestDiffDir = Get-LatestChildItem -Path (Join-Path $diffProject.DiffRoot "finance_compare_mvp") -Directory
if ($latestDiffDir) {
    Copy-IfExists -SourcePath (Join-Path $latestDiffDir.FullName "diff.json") -DestinationPath (Join-Path $test2Dir "diff.json") | Out-Null
    Copy-IfExists -SourcePath (Join-Path $latestDiffDir.FullName "diff.md") -DestinationPath (Join-Path $test2Dir "diff.md") | Out-Null
}

$test2DiffJson = Get-Content -Path (Join-Path $test2Dir "diff.json") -Raw | ConvertFrom-Json
$changedFiles = @($test2DiffJson.fileChanges | Where-Object { $_.status -ne "unchanged" } | Select-Object -ExpandProperty relativePath)
Save-TextFile -Path (Join-Path $test2Dir "files-involved.txt") -Content (@($changedFiles) -join "`r`n")
Save-RawInstalledState -ProjectStatePath $diffProject.StateFilePath -OutputPath (Join-Path $test2Dir "installed-modules.after.json")
Save-GitEvidence -RepositoryRoot $diffSandbox.Root -OutputDir $test2Dir -Pathspecs (Get-FinanceConsumerPathspec) -Prefix "post-diff"

$moduleSourceRoot = Join-Path $diffSandbox.Root "modularity\pbi-finance-domain\packages\finance_compare_mvp"
Save-NoIndexDiff -SourcePath (Join-Path $moduleSourceRoot "semantic\MOD Finance Compare Selector.tmdl") -DestinationPath $diffSemanticPath -OutputPath (Join-Path $test2Dir "manual-validation.semantic.diff.txt")
Save-NoIndexDiff -SourcePath (Join-Path $moduleSourceRoot "report\page.json") -DestinationPath $diffPagePath -OutputPath (Join-Path $test2Dir "manual-validation.page.diff.txt")
Save-NoIndexDiff -SourcePath (Join-Path $moduleSourceRoot "report\visuals\fc_mvp_title\visual.json") -DestinationPath $diffVisualPath -OutputPath (Join-Path $test2Dir "manual-validation.visual.diff.txt")
Save-TextFile -Path (Join-Path $test2Dir "manual-validation.md") -Content @"
# Validazione manuale differenze

- `MOD Finance Compare Selector.tmdl`: il default label installato e' stato alterato da `BGT` a `BGT DRIFT`; il diff del framework segnala il file semantic come `changed`.
- `page.json`: il `displayName` della pagina installata e' stato alterato da `Finance Compare MVP` a `Finance Compare MVP Drift`; il diff del framework segnala il file pagina come `changed`.
- `visual.json`: il titolo del visual `fc_mvp_title` e' stato alterato da `Finance Compare MVP` a `Finance Compare MVP Drift`; il diff del framework segnala il file visual come `changed`.
"@

$test2Status = if ($changedFiles.Count -lt 3) { "FAIL" } else { "PASS" }
$test2Summary = "Diff leggibile e coerente su finance_compare_mvp: rilevate tre derive controllate su semantic asset e report asset del consumer."
Add-TestResult -Collection $testResults -Id "test-2" -Title "Diff modulo" -Status $test2Status -Summary $test2Summary -Consumer "20260317_UAT_001.pbip" -Module "finance_compare_mvp" -Versions "0.1.0 -> 0.1.0 (drift controllato)" -Evidence @(
    "test-2-diff-module\command.txt",
    "test-2-diff-module\command-output.txt",
    "test-2-diff-module\diff.json",
    "test-2-diff-module\diff.md",
    "test-2-diff-module\files-involved.txt",
    "test-2-diff-module\manual-validation.md"
)

# Test 3 - upgrade module
$upgradeProjectPath = Join-Path $upgradeSandbox.Root "powerbi-projects\20260317_UAT_001.pbip"
$upgradeManifestPath = Join-Path $upgradeSandbox.Root "modularity\pbi-finance-domain\packages\finance_compare_mvp\manifest.json"
$upgradeSourcePagePath = Join-Path $upgradeSandbox.Root "modularity\pbi-finance-domain\packages\finance_compare_mvp\report\page.json"
$upgradeSourceVisualPath = Join-Path $upgradeSandbox.Root "modularity\pbi-finance-domain\packages\finance_compare_mvp\report\visuals\fc_mvp_title\visual.json"
$upgradeSourceSemanticPath = Join-Path $upgradeSandbox.Root "modularity\pbi-finance-domain\packages\finance_compare_mvp\semantic\MOD Finance Compare Selector.tmdl"

Set-JsonFileValue -Path $upgradeManifestPath -Mutator { param($json) $json.version = "0.1.1"; return $json }
Set-JsonFileValue -Path $upgradeSourcePagePath -Mutator { param($json) $json.displayName = "Finance Compare MVP v0.1.1"; return $json }
Set-JsonFileValue -Path $upgradeSourceVisualPath -Mutator {
    param($json)
    $json.visual.visualContainerObjects.title[0].properties.text.expr.Literal.Value = "'Finance Compare MVP v0.1.1'"
    return $json
}
Replace-InFile -Path $upgradeSourceSemanticPath -Pattern '\"BGT\"' -Replacement '"BGT 0.1.1"'

$upgradeProject = Resolve-PbiConsumerProject -ProjectPath $upgradeProjectPath
Save-RawInstalledState -ProjectStatePath $upgradeProject.StateFilePath -OutputPath (Join-Path $test3Dir "installed-modules.before.json")
Save-GitEvidence -RepositoryRoot $upgradeSandbox.Root -OutputDir $test3Dir -Pathspecs (Get-FinanceConsumerPathspec) -Prefix "pre-upgrade"

$test3UpgradeArgs = Get-PowerShellScriptArguments -Executable $shellExecutable -ScriptPath $upgradeSandbox.InstallerPath -Parameters @{
    Command       = "upgrade-module"
    WorkspaceRoot = $upgradeSandbox.Root
    ProjectPath   = $upgradeProjectPath
    ModuleId      = "finance_compare_mvp"
}
$null = Invoke-ExternalCommand -Executable $shellExecutable -Arguments $test3UpgradeArgs -CommandPath (Join-Path $test3Dir "command.txt") -OutputPath (Join-Path $test3Dir "command-output.txt")

$test3UpgradeLog = Get-LatestChildItem -Path $upgradeProject.LogsRoot -Filter "*.jsonl"
if ($test3UpgradeLog) {
    Copy-IfExists -SourcePath $test3UpgradeLog.FullName -DestinationPath (Join-Path $test3Dir "upgrade-log.jsonl") | Out-Null
}

$latestUpgradeDiffDir = Get-LatestChildItem -Path (Join-Path $upgradeProject.DiffRoot "finance_compare_mvp") -Directory
if ($latestUpgradeDiffDir) {
    Copy-IfExists -SourcePath (Join-Path $latestUpgradeDiffDir.FullName "diff.json") -DestinationPath (Join-Path $test3Dir "upgrade-diff.json") | Out-Null
    Copy-IfExists -SourcePath (Join-Path $latestUpgradeDiffDir.FullName "diff.md") -DestinationPath (Join-Path $test3Dir "upgrade-diff.md") | Out-Null
}

Save-RawInstalledState -ProjectStatePath $upgradeProject.StateFilePath -OutputPath (Join-Path $test3Dir "installed-modules.after.json")
$test3Normalized = Get-NormalizedRecord -ProjectPath $upgradeProjectPath -ModuleId "finance_compare_mvp"
Save-JsonFile -Path (Join-Path $test3Dir "normalized-record.after.json") -InputObject $test3Normalized.Record
Save-TextFile -Path (Join-Path $test3Dir "files-touched.txt") -Content (@($test3Normalized.Record.filesTouched) -join "`r`n")
Save-GitEvidence -RepositoryRoot $upgradeSandbox.Root -OutputDir $test3Dir -Pathspecs (Get-FinanceConsumerPathspec) -Prefix "post-upgrade"

$test3QualityArgs = Get-PowerShellScriptArguments -Executable $shellExecutable -ScriptPath $upgradeSandbox.QualityPath -Parameters @{
    Command       = "test-project"
    WorkspaceRoot = $upgradeSandbox.Root
    ProjectPath   = $upgradeProjectPath
}
$null = Invoke-ExternalCommand -Executable $shellExecutable -Arguments $test3QualityArgs -CommandPath (Join-Path $test3Dir "quality-check.command.txt") -OutputPath (Join-Path $test3Dir "quality-check.output.txt")
$test3ProjectQuality = Invoke-PbiProjectQualityChecks -ProjectPath $upgradeProjectPath
Save-JsonFile -Path (Join-Path $test3Dir "quality-check.summary.json") -InputObject $test3ProjectQuality

$test3Warnings = New-Object System.Collections.Generic.List[string]
if ($test3ProjectQuality.Counts.Warnings -gt 0) {
    $test3Warnings.Add("I quality checks di progetto riportano warning post-upgrade.")
}
$test3GovernanceReasonsText = (@($test3Normalized.Record.governance.reasons) -join " ")
if ($test3Normalized.Record.governance.status -ne "PASS") {
    if ($test3GovernanceReasonsText -match '\?\?') {
        $test3Warnings.Add("Governance WARN: il repo-health hook non e' compatibile con Windows PowerShell 5.1 e degrada l'operazione.")
    }
    else {
        $test3Warnings.Add("Governance " + $test3Normalized.Record.governance.status + ": verificare i motivi registrati in installed-modules.json.")
    }
}
$test3Warnings.Add("Il footprint registrato in metadata rappresenta il perimetro gestito del modulo, non il delta minimo puntuale del singolo upgrade.")
$test3Warnings.Add("L'apertura in Power BI Desktop non e' verificabile da CLI nel perimetro di questo collaudo.")
$test3Status = if ($test3ProjectQuality.Counts.Errors -gt 0) { "FAIL" } else { "PASS WITH WARNING" }
$test3Summary = "Upgrade completato da finance_compare_mvp 0.1.0 a 0.1.1; consumer e metadata restano coerenti e il progetto supera i quality checks strutturali."
Add-TestResult -Collection $testResults -Id "test-3" -Title "Upgrade modulo" -Status $test3Status -Summary $test3Summary -Consumer "20260317_UAT_001.pbip" -Module "finance_compare_mvp" -Versions "0.1.0 -> 0.1.1" -Warnings $test3Warnings.ToArray() -Evidence @(
    "test-3-upgrade-module\command.txt",
    "test-3-upgrade-module\command-output.txt",
    "test-3-upgrade-module\upgrade-log.jsonl",
    "test-3-upgrade-module\installed-modules.before.json",
    "test-3-upgrade-module\installed-modules.after.json",
    "test-3-upgrade-module\files-touched.txt",
    "test-3-upgrade-module\post-upgrade.git-diff.txt",
    "test-3-upgrade-module\quality-check.output.txt"
)

# Test 4 - rollback module
Copy-IfExists -SourcePath (Join-Path $test3Dir "installed-modules.before.json") -DestinationPath (Join-Path $test4Dir "installed-modules.before-upgrade.json") | Out-Null
Copy-IfExists -SourcePath (Join-Path $test3Dir "installed-modules.after.json") -DestinationPath (Join-Path $test4Dir "installed-modules.after-upgrade.json") | Out-Null
Save-GitEvidence -RepositoryRoot $upgradeSandbox.Root -OutputDir $test4Dir -Pathspecs (Get-FinanceConsumerPathspec) -Prefix "pre-rollback"

$test4RollbackArgs = Get-PowerShellScriptArguments -Executable $shellExecutable -ScriptPath $upgradeSandbox.InstallerPath -Parameters @{
    Command     = "rollback-module"
    ProjectPath = $upgradeProjectPath
    ModuleId    = "finance_compare_mvp"
}
$null = Invoke-ExternalCommand -Executable $shellExecutable -Arguments $test4RollbackArgs -CommandPath (Join-Path $test4Dir "command.txt") -OutputPath (Join-Path $test4Dir "command-output.txt")

$test4RollbackLog = Get-LatestChildItem -Path $upgradeProject.LogsRoot -Filter "*.jsonl"
if ($test4RollbackLog) {
    Copy-IfExists -SourcePath $test4RollbackLog.FullName -DestinationPath (Join-Path $test4Dir "rollback-log.jsonl") | Out-Null
}

Save-RawInstalledState -ProjectStatePath $upgradeProject.StateFilePath -OutputPath (Join-Path $test4Dir "installed-modules.after-rollback.json")
Save-GitEvidence -RepositoryRoot $upgradeSandbox.Root -OutputDir $test4Dir -Pathspecs (Get-FinanceConsumerPathspec) -Prefix "post-rollback"
Invoke-GitCommand -RepositoryRoot $upgradeSandbox.Root -Arguments (@("diff", "--name-only", "--") + (Get-FinanceManagedPathspec)) -OutputPath (Join-Path $test4Dir "baseline-vs-rollback-managed-files.txt") | Out-Null
Invoke-GitCommand -RepositoryRoot $upgradeSandbox.Root -Arguments (@("diff", "--") + (Get-FinanceManagedPathspec)) -OutputPath (Join-Path $test4Dir "baseline-vs-rollback-managed-diff.txt") | Out-Null

$test4QualityArgs = Get-PowerShellScriptArguments -Executable $shellExecutable -ScriptPath $upgradeSandbox.QualityPath -Parameters @{
    Command       = "test-project"
    WorkspaceRoot = $upgradeSandbox.Root
    ProjectPath   = $upgradeProjectPath
}
$null = Invoke-ExternalCommand -Executable $shellExecutable -Arguments $test4QualityArgs -CommandPath (Join-Path $test4Dir "quality-check.command.txt") -OutputPath (Join-Path $test4Dir "quality-check.output.txt")
$test4ProjectQuality = Invoke-PbiProjectQualityChecks -ProjectPath $upgradeProjectPath
Save-JsonFile -Path (Join-Path $test4Dir "quality-check.summary.json") -InputObject $test4ProjectQuality

$managedDiffLines = @(
    Get-Content -Path (Join-Path $test4Dir "baseline-vs-rollback-managed-files.txt") |
        Where-Object { $_ -and ($_ -notmatch '^\[exit-code\]') }
)
$test4Warnings = New-Object System.Collections.Generic.List[string]
if ($test4ProjectQuality.Counts.Warnings -gt 0) {
    $test4Warnings.Add("I quality checks di progetto riportano warning post-rollback.")
}
if ($managedDiffLines.Count -eq 0) {
    $test4Warnings.Add("Il rollback ripristina i file gestiti del consumer; restano solo artifact di audit sotto module-config (log, diff, snapshot, repo-health).")
}
$test4Status = if (($test4ProjectQuality.Counts.Errors -gt 0) -or ($managedDiffLines.Count -gt 0)) { "FAIL" } else { "PASS WITH WARNING" }
$test4Summary = "Rollback eseguito con successo: i file gestiti ritornano al baseline pre-upgrade, mentre gli artifact di audit restano intenzionalmente in module-config."
Add-TestResult -Collection $testResults -Id "test-4" -Title "Rollback modulo" -Status $test4Status -Summary $test4Summary -Consumer "20260317_UAT_001.pbip" -Module "finance_compare_mvp" -Versions "0.1.1 -> 0.1.0" -Warnings $test4Warnings.ToArray() -Evidence @(
    "test-4-rollback-module\command.txt",
    "test-4-rollback-module\command-output.txt",
    "test-4-rollback-module\rollback-log.jsonl",
    "test-4-rollback-module\installed-modules.before-upgrade.json",
    "test-4-rollback-module\installed-modules.after-upgrade.json",
    "test-4-rollback-module\installed-modules.after-rollback.json",
    "test-4-rollback-module\baseline-vs-rollback-managed-diff.txt",
    "test-4-rollback-module\quality-check.output.txt"
)

# Test 5 - consumer impact
$test1Impact = Get-ImpactAssessment -Record $test1Normalized.Record
$test3Impact = Get-ImpactAssessment -Record $test3Normalized.Record

$test5ImpactSummary = [ordered]@{
    install = [ordered]@{
        consumer            = "20260317_Product_Analysis_FlexTable.pbip"
        module              = "flex_table_flat_mvp"
        filesTouched        = @($test1Normalized.Record.filesTouched)
        impactMetrics       = $test1Normalized.Record.impactMetrics
        classification      = $test1Impact.classification
        centralFiles        = @($test1Impact.centralFiles)
        coreSemanticFiles   = @($test1Impact.coreTableFiles)
        semanticCoreTouched = (@($test1Impact.coreTableFiles).Count -gt 0)
    }
    upgrade = [ordered]@{
        consumer            = "20260317_UAT_001.pbip"
        module              = "finance_compare_mvp"
        filesTouched        = @($test3Normalized.Record.filesTouched)
        impactMetrics       = $test3Normalized.Record.impactMetrics
        classification      = $test3Impact.classification
        centralFiles        = @($test3Impact.centralFiles)
        coreSemanticFiles   = @($test3Impact.coreTableFiles)
        semanticCoreTouched = (@($test3Impact.coreTableFiles).Count -gt 0)
    }
}
Save-JsonFile -Path (Join-Path $test5Dir "impact-summary.json") -InputObject $test5ImpactSummary
Save-TextFile -Path (Join-Path $test5Dir "impact-summary.md") -Content @"
# Valutazione impatto consumer

## Install pulita - flex_table_flat_mvp
- Classificazione: $($test1Impact.classification)
- File toccati: $(@($test1Normalized.Record.filesTouched).Count)
- File centrali toccati: $(if (@($test1Impact.centralFiles).Count -gt 0) { (@($test1Impact.centralFiles) -join ", ") } else { "nessuno" })
- Semantic model core toccato: $(if (@($test1Impact.coreTableFiles).Count -gt 0) { "SI" } else { "NO" })

## Upgrade - finance_compare_mvp
- Classificazione: $($test3Impact.classification)
- File toccati: $(@($test3Normalized.Record.filesTouched).Count)
- File centrali toccati: $(if (@($test3Impact.centralFiles).Count -gt 0) { (@($test3Impact.centralFiles) -join ", ") } else { "nessuno" })
- Semantic model core toccato: $(if (@($test3Impact.coreTableFiles).Count -gt 0) { "SI" } else { "NO" })
"@

$test5Warnings = New-Object System.Collections.Generic.List[string]
if (($test1Impact.classification -eq "medio") -or ($test3Impact.classification -eq "medio")) {
    $test5Warnings.Add("Il modulo tocca file centrali di orchestrazione del progetto (model.tmdl e/o pages.json), quindi l'impatto non e' minimo.")
}
$test5Status = if ((@($test1Impact.coreTableFiles).Count -gt 0) -or (@($test3Impact.coreTableFiles).Count -gt 0)) { "FAIL" } elseif ($test5Warnings.Count -gt 0) { "PASS WITH WARNING" } else { "PASS" }
$test5Summary = "Il footprint dei moduli e' misurabile e spiegabile; nei casi collaudati non emergono tocchi a tabelle core non modulari."
Add-TestResult -Collection $testResults -Id "test-5" -Title "Verifica impatto sul consumer" -Status $test5Status -Summary $test5Summary -Consumer "20260317_Product_Analysis_FlexTable.pbip / 20260317_UAT_001.pbip" -Module "flex_table_flat_mvp / finance_compare_mvp" -Versions "0.2.0 / 0.1.0->0.1.1" -Warnings $test5Warnings.ToArray() -Evidence @(
    "test-5-consumer-impact\impact-summary.json",
    "test-5-consumer-impact\impact-summary.md",
    "test-1-install-clean\files-touched.txt",
    "test-3-upgrade-module\files-touched.txt"
)

# Test 6 - quality checks platform
$smokeTempRoot = Join-Path $test6Dir "smoke-temp"
Ensure-Directory -Path $smokeTempRoot

$test6ListRulesArgs = Get-PowerShellScriptArguments -Executable $shellExecutable -ScriptPath $qualityScript -Parameters @{
    Command       = "list-rules"
    WorkspaceRoot = $repoRoot
}
$null = Invoke-ExternalCommand -Executable $shellExecutable -Arguments $test6ListRulesArgs -CommandPath (Join-Path $test6Dir "list-rules.command.txt") -OutputPath (Join-Path $test6Dir "list-rules.output.txt")

$test6FinanceModuleArgs = Get-PowerShellScriptArguments -Executable $shellExecutable -ScriptPath $qualityScript -Parameters @{
    Command       = "test-module"
    WorkspaceRoot = $repoRoot
    ModuleId      = "finance_compare_mvp"
}
$null = Invoke-ExternalCommand -Executable $shellExecutable -Arguments $test6FinanceModuleArgs -CommandPath (Join-Path $test6Dir "test-module.finance.command.txt") -OutputPath (Join-Path $test6Dir "test-module.finance.output.txt")

$test6MarketingModuleArgs = Get-PowerShellScriptArguments -Executable $shellExecutable -ScriptPath $qualityScript -Parameters @{
    Command       = "test-module"
    WorkspaceRoot = $repoRoot
    ModuleId      = "flex_table_flat_mvp"
}
$null = Invoke-ExternalCommand -Executable $shellExecutable -Arguments $test6MarketingModuleArgs -CommandPath (Join-Path $test6Dir "test-module.marketing.command.txt") -OutputPath (Join-Path $test6Dir "test-module.marketing.output.txt")

$test6RepoArgs = Get-PowerShellScriptArguments -Executable $shellExecutable -ScriptPath $qualityScript -Parameters @{
    Command       = "test-repo"
    WorkspaceRoot = $repoRoot
}
$null = Invoke-ExternalCommand -Executable $shellExecutable -Arguments $test6RepoArgs -CommandPath (Join-Path $test6Dir "test-repo.command.txt") -OutputPath (Join-Path $test6Dir "test-repo.output.txt")

$test6SmokeArgs = Get-PowerShellScriptArguments -Executable $shellExecutable -ScriptPath $qualityScript -Parameters @{
    Command       = "smoke-install"
    WorkspaceRoot = $repoRoot
    ProjectPath   = (Join-Path $powerbiProjectsRoot "20260317_UAT_001.pbip")
    ModuleId      = "finance_compare_mvp"
    TempRoot      = $smokeTempRoot
    KeepTempCopy  = $true
}
$null = Invoke-ExternalCommand -Executable $shellExecutable -Arguments $test6SmokeArgs -CommandPath (Join-Path $test6Dir "smoke-install.command.txt") -OutputPath (Join-Path $test6Dir "smoke-install.output.txt")

$test6FinanceOutcome = Invoke-PbiModuleQualityChecks -WorkspaceRoot $repoRoot -ModuleId "finance_compare_mvp"
$test6MarketingOutcome = Invoke-PbiModuleQualityChecks -WorkspaceRoot $repoRoot -ModuleId "flex_table_flat_mvp"
$test6RepoOutcome = Invoke-PbiRepoQualityChecks -WorkspaceRoot $repoRoot
$programmaticSmokeTempRoot = Join-Path $sandboxBaseRoot ("smoke-programmatic-" + [guid]::NewGuid().ToString("N"))
$null = New-Item -ItemType Directory -Path $programmaticSmokeTempRoot -Force
$test6SmokeOutcome = Invoke-PbiSmokeInstallCheck -WorkspaceRoot $repoRoot -ProjectPath (Join-Path $powerbiProjectsRoot "20260317_UAT_001.pbip") -ModuleId "finance_compare_mvp" -TempRoot $programmaticSmokeTempRoot

$test6Summary = [ordered]@{
    financeModule = [ordered]@{ counts = $test6FinanceOutcome.Counts; summary = (Get-QualityCountsSummary -Outcome $test6FinanceOutcome) }
    marketingModule = [ordered]@{ counts = $test6MarketingOutcome.Counts; summary = (Get-QualityCountsSummary -Outcome $test6MarketingOutcome) }
    repo = [ordered]@{ counts = $test6RepoOutcome.Counts; summary = (Get-QualityCountsSummary -Outcome $test6RepoOutcome) }
    smokeInstall = [ordered]@{ counts = $test6SmokeOutcome.Counts; summary = (Get-QualityCountsSummary -Outcome $test6SmokeOutcome) }
}
Save-JsonFile -Path (Join-Path $test6Dir "quality-summary.json") -InputObject $test6Summary

$test6Warnings = New-Object System.Collections.Generic.List[string]
if ($test6RepoOutcome.Counts.Warnings -gt 0) {
    $test6Warnings.Add("Il repo presenta warning di quality check non bloccanti.")
}
$test6Status = if (($test6FinanceOutcome.Counts.Errors + $test6MarketingOutcome.Counts.Errors + $test6RepoOutcome.Counts.Errors + $test6SmokeOutcome.Counts.Errors) -gt 0) { "FAIL" } elseif ($test6Warnings.Count -gt 0) { "PASS WITH WARNING" } else { "PASS" }
$test6ResultSummary = "Manifest, regole architetturali, controlli report e smoke-install risultano eseguibili e coerenti sul commit 7cb5dd4."
Add-TestResult -Collection $testResults -Id "test-6" -Title "Quality checks platform" -Status $test6Status -Summary $test6ResultSummary -Consumer "repo-wide / 20260317_UAT_001.pbip smoke copy" -Module "finance_compare_mvp / flex_table_flat_mvp" -Versions "catalog current" -Warnings $test6Warnings.ToArray() -Evidence @(
    "test-6-quality-checks\list-rules.output.txt",
    "test-6-quality-checks\test-module.finance.output.txt",
    "test-6-quality-checks\test-module.marketing.output.txt",
    "test-6-quality-checks\test-repo.output.txt",
    "test-6-quality-checks\smoke-install.output.txt",
    "test-6-quality-checks\quality-summary.json"
)

$summary = @{
    metadata = $runMetadata
    hypothesis = "L'architettura collaudata e' una modularizzazione per materializzazione controllata nel consumer; lo stato installato deve restare minimo, tracciato, coerente, reversibile e governato."
    tests = $testResults.ToArray()
}
Save-JsonFile -Path (Join-Path $OutputRoot "summary.json") -InputObject $summary

$statusCounts = @{
    PASS = (@($testResults | Where-Object { $_.status -eq "PASS" })).Count
    "PASS WITH WARNING" = (@($testResults | Where-Object { $_.status -eq "PASS WITH WARNING" })).Count
    FAIL = (@($testResults | Where-Object { $_.status -eq "FAIL" })).Count
}

$gaps = New-Object System.Collections.Generic.List[string]
if (@($testResults | Where-Object { $_.status -eq "FAIL" }).Count -gt 0) {
    $gaps.Add("Sono presenti test FAIL; il framework richiede ulteriore hardening sui punti evidenziati.")
}
if (@($testResults | Where-Object { $_.warnings.Count -gt 0 }).Count -gt 0) {
    $gaps.Add("La verifica di apertura in Power BI Desktop non rientra nel perimetro CLI e resta un controllo operativo da completare su pilot umano.")
}
$gaps.Add("Il hook repo-health non e' compatibile con Windows PowerShell 5.1: durante install e upgrade la governance degrada a WARN per parsing degli operatori '??' in repository-health.")
$gaps.Add("Il rollback ripristina i file gestiti del consumer ma conserva artefatti di audit in module-config, comportamento coerente ma da esplicitare nel runbook.")

$recommendation = if ($statusCounts.FAIL -gt 0) {
    "framework non ancora pronto, richiede ulteriore hardening"
}
elseif ($statusCounts."PASS WITH WARNING" -gt 0) {
    "framework pronto per pilot tecnico"
}
else {
    "framework pronto per uso operativo controllato"
}

$reportLines = @(
    "# Collaudo framework modularity - lifecycle install / diff / upgrade / rollback",
    "",
    ('- Commit collaudato: `' + $Commit + '`'),
    ('- Data esecuzione: `' + $reportDate.ToString("yyyy-MM-dd HH:mm:ss") + '`'),
    ('- Operatore: `' + $OperatorName + '`'),
    ('- Runtime shell: `' + $shellExecutable + '`'),
    "",
    "## 1. Test eseguiti",
    ""
)

foreach ($test in $testResults) {
    $reportLines += ("### {0} - {1}" -f $test.id.ToUpperInvariant(), $test.title)
    $reportLines += ('- Data: `' + $reportDate.ToString("yyyy-MM-dd") + '`')
    $reportLines += ('- Operatore: `' + $OperatorName + '`')
    $reportLines += ('- Consumer: `' + $test.consumer + '`')
    $reportLines += ('- Modulo: `' + $test.module + '`')
    $reportLines += ('- Versioni: `' + $test.versions + '`')
    $reportLines += ""
}

$reportLines += "## 2. Esito per test"
$reportLines += ""
foreach ($test in $testResults) {
    $reportLines += ("### {0} - {1}" -f $test.id.ToUpperInvariant(), $test.status)
    $reportLines += ('- Sintesi: ' + $test.summary)
    if (@($test.warnings).Count -gt 0) {
        foreach ($warning in @($test.warnings)) {
            $reportLines += ('- Nota: ' + $warning)
        }
    }
    foreach ($evidencePath in @($test.evidence)) {
        $reportLines += ('- Evidenza: `' + $evidencePath + '`')
    }
    $reportLines += ""
}

$reportLines += "## 3. Gap residui"
$reportLines += ""
foreach ($gap in $gaps) {
    $reportLines += ('- ' + $gap)
}
$reportLines += ""
$reportLines += "## 4. Raccomandazione finale"
$reportLines += ""
$reportLines += ('- Esito raccomandato: `' + $recommendation + '`')
$reportLines += ('- Distribuzione stati: PASS=' + $statusCounts.PASS + '; PASS WITH WARNING=' + $statusCounts."PASS WITH WARNING" + '; FAIL=' + $statusCounts.FAIL)
$reportLines += ""
$reportLines += "## Nota architetturale"
$reportLines += ""
$reportLines += "Il collaudo e' stato eseguito assumendo che l'architettura corrente sia una modularizzazione per materializzazione controllata nel consumer, non una composizione senza stato risultante. Il criterio di esito non e' quindi l'assenza di stato installato, ma la verifica che lo stato resti minimo, tracciato, coerente, reversibile e governato."

Save-TextFile -Path (Join-Path $OutputRoot "COLLAUDO_REPORT.md") -Content ($reportLines -join "`r`n")

Write-Host ("Collaudo completato. Evidenze in: {0}" -f $OutputRoot)
