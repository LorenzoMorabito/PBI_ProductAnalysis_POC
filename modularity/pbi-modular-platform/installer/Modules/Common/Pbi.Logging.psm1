Set-StrictMode -Version Latest

$script:PbiOperationContext = $null

function New-PbiOperationContext {
    param(
        [Parameter(Mandatory = $true)][string]$Command,
        [string]$ProjectId,
        [string]$ModuleId,
        [string]$LogRoot
    )

    $timestampKey = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssfffZ")
    $operationId = "{0}-{1}" -f $timestampKey, ([guid]::NewGuid().ToString("N").Substring(0, 8))

    if (-not $LogRoot) {
        $LogRoot = Join-Path ([System.IO.Path]::GetTempPath()) "pbi-modular-platform-logs"
    }

    if (-not (Test-Path $LogRoot)) {
        New-Item -ItemType Directory -Path $LogRoot -Force | Out-Null
    }

    return [PSCustomObject]@{
        operationId = $operationId
        command     = $Command
        projectId   = $ProjectId
        moduleId    = $ModuleId
        startedAt   = (Get-Date).ToUniversalTime().ToString("o")
        logFilePath = Join-Path $LogRoot ($operationId + ".jsonl")
    }
}

function Set-PbiOperationContext {
    param([Parameter(Mandatory = $true)]$Context)
    $script:PbiOperationContext = $Context
}

function Get-PbiOperationContext {
    return $script:PbiOperationContext
}

function Clear-PbiOperationContext {
    $script:PbiOperationContext = $null
}

function Write-PbiLog {
    param(
        [Parameter(Mandatory = $true)][ValidateSet("Debug", "Info", "Warning", "Error", "Success")][string]$Level,
        [Parameter(Mandatory = $true)][string]$Message,
        $Data
    )

    $context = Get-PbiOperationContext
    $prefix = "[{0}]" -f $Level.ToUpperInvariant()

    switch ($Level) {
        "Warning" { Write-Warning $Message }
        "Error" { Write-Error $Message -ErrorAction Continue }
        default { Write-Host ("{0} {1}" -f $prefix, $Message) }
    }

    if ($context -and $context.logFilePath) {
        $entry = [ordered]@{
            timestamp   = (Get-Date).ToUniversalTime().ToString("o")
            level       = $Level
            message     = $Message
            operationId = $context.operationId
            command     = $context.command
            projectId   = $context.projectId
            moduleId    = $context.moduleId
        }

        if ($null -ne $Data) {
            $entry["data"] = $Data
        }

        Add-Content -Path $context.logFilePath -Value (($entry | ConvertTo-Json -Depth 20 -Compress))
    }
}

function Write-PbiInfo {
    param([Parameter(Mandatory = $true)][string]$Message, $Data)
    Write-PbiLog -Level "Info" -Message $Message -Data $Data
}

function Write-PbiWarning {
    param([Parameter(Mandatory = $true)][string]$Message, $Data)
    Write-PbiLog -Level "Warning" -Message $Message -Data $Data
}

function Write-PbiSuccess {
    param([Parameter(Mandatory = $true)][string]$Message, $Data)
    Write-PbiLog -Level "Success" -Message $Message -Data $Data
}

function Write-PbiError {
    param([Parameter(Mandatory = $true)][string]$Message, $Data)
    Write-PbiLog -Level "Error" -Message $Message -Data $Data
}

Export-ModuleMember -Function New-PbiOperationContext, Set-PbiOperationContext, Get-PbiOperationContext, Clear-PbiOperationContext, Write-PbiLog, Write-PbiInfo, Write-PbiWarning, Write-PbiSuccess, Write-PbiError
