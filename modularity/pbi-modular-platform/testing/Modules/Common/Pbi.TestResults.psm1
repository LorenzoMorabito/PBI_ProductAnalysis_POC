function New-PbiQualityResult {
    param(
        [Parameter(Mandatory = $true)][string]$Scope,
        [Parameter(Mandatory = $true)][string]$Target,
        [Parameter(Mandatory = $true)][string]$RuleId,
        [Parameter(Mandatory = $true)][ValidateSet("Error", "Warning", "Info")][string]$Severity,
        [Parameter(Mandatory = $true)][string]$Message,
        [string]$Path
    )

    return [PSCustomObject]@{
        Scope    = $Scope
        Target   = $Target
        RuleId   = $RuleId
        Severity = $Severity
        Message  = $Message
        Path     = $Path
    }
}

function Get-PbiQualityResultCounts {
    param([Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Results)

    return [PSCustomObject]@{
        Errors   = @($Results | Where-Object { $_.Severity -eq "Error" }).Count
        Warnings = @($Results | Where-Object { $_.Severity -eq "Warning" }).Count
        Infos    = @($Results | Where-Object { $_.Severity -eq "Info" }).Count
        Total    = @($Results).Count
    }
}

function Test-PbiQualityHasErrors {
    param([Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Results)

    return (@($Results | Where-Object { $_.Severity -eq "Error" }).Count -gt 0)
}

Export-ModuleMember -Function New-PbiQualityResult, Get-PbiQualityResultCounts, Test-PbiQualityHasErrors
