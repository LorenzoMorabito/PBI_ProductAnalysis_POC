function Write-PbiInfo {
    param([Parameter(Mandatory = $true)][string]$Message)
    Write-Host "[INFO] $Message"
}

function Write-PbiWarning {
    param([Parameter(Mandatory = $true)][string]$Message)
    Write-Warning $Message
}

function Write-PbiSuccess {
    param([Parameter(Mandatory = $true)][string]$Message)
    Write-Host "[OK] $Message"
}

Export-ModuleMember -Function Write-PbiInfo, Write-PbiWarning, Write-PbiSuccess
