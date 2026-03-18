function Get-PbiInstallerWorkspaceRoot {
    param(
        [string]$WorkspaceRoot,
        [string]$ScriptRoot
    )

    if ($WorkspaceRoot) {
        return (Resolve-Path $WorkspaceRoot).Path
    }

    $currentPath = (Resolve-Path $ScriptRoot).Path

    while ($currentPath) {
        $directoryNames = @(
            Get-ChildItem -Path $currentPath -Directory -ErrorAction SilentlyContinue |
                Select-Object -ExpandProperty Name
        )
        $newLayoutDetected = (
            ($directoryNames -contains "modularity") -and
            ($directoryNames -contains "powerbi-projects") -and
            ($directoryNames -contains "repository-health")
        )
        $legacyDomainDirectories = @(Get-ChildItem -Path $currentPath -Directory -Filter "pbi-*-domain" -ErrorAction SilentlyContinue)
        $legacyLayoutDetected = (
            ($legacyDomainDirectories.Count -gt 0 -or ($directoryNames -contains "pbi-modular-platform")) -and
            (@(Get-ChildItem -Path $currentPath -File -Filter "*.pbip" -ErrorAction SilentlyContinue).Count -gt 0)
        )

        if ($newLayoutDetected -or $legacyLayoutDetected) {
            return $currentPath
        }

        $parentPath = Split-Path $currentPath -Parent

        if ($parentPath -eq $currentPath) {
            break
        }

        $currentPath = $parentPath
    }

    throw "Unable to resolve the workspace root automatically. Specify -WorkspaceRoot explicitly."
}

function Resolve-PbiPath {
    param(
        [Parameter(Mandatory = $true)][string]$BasePath,
        [Parameter(Mandatory = $true)][string]$RelativePath
    )

    $joinedPath = Join-Path $BasePath $RelativePath
    return [System.IO.Path]::GetFullPath($joinedPath)
}

function Read-PbiJsonFile {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path $Path)) {
        throw "JSON file not found: $Path"
    }

    return (Get-Content $Path -Raw | ConvertFrom-Json -Depth 100)
}

function Write-PbiJsonFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)]$InputObject
    )

    $json = $InputObject | ConvertTo-Json -Depth 100
    Set-Content -Path $Path -Value $json -Encoding utf8
}

function Ensure-PbiDirectory {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

Export-ModuleMember -Function Get-PbiInstallerWorkspaceRoot, Resolve-PbiPath, Read-PbiJsonFile, Write-PbiJsonFile, Ensure-PbiDirectory
