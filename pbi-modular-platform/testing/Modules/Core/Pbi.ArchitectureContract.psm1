function Get-PbiArchitectureContractPath {
    $testingRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    return (Join-Path $testingRoot "Config/architecture-boundary.json")
}

function Get-PbiArchitectureContract {
    $contractPath = Get-PbiArchitectureContractPath

    if (-not (Test-Path $contractPath)) {
        throw "Architecture contract file '$contractPath' does not exist."
    }

    return (Read-PbiJsonFile -Path $contractPath)
}

Export-ModuleMember -Function Get-PbiArchitectureContractPath, Get-PbiArchitectureContract
