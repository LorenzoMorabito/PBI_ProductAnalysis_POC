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

function ConvertFrom-PbiJsonText {
    param([Parameter(Mandatory = $true)][string]$Text)

    if ($PSVersionTable.PSVersion.Major -ge 6) {
        return ($Text | ConvertFrom-Json -Depth 100)
    }

    return ($Text | ConvertFrom-Json)
}

function ConvertTo-PbiJsonText {
    param(
        [Parameter(Mandatory = $true)]$InputObject,
        [switch]$Compress
    )

    if ($Compress) {
        return ($InputObject | ConvertTo-Json -Depth 100 -Compress)
    }

    return ($InputObject | ConvertTo-Json -Depth 100)
}

function Resolve-PbiPath {
    param(
        [Parameter(Mandatory = $true)][string]$BasePath,
        [Parameter(Mandatory = $true)][string]$RelativePath
    )

    $joinedPath = Join-Path $BasePath $RelativePath
    return [System.IO.Path]::GetFullPath($joinedPath)
}

function Get-PbiRelativePath {
    param(
        [Parameter(Mandatory = $true)][string]$BasePath,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $resolvedBasePath = (Resolve-Path $BasePath).Path
    $resolvedPath = [System.IO.Path]::GetFullPath($Path)
    $basePathForUri = $resolvedBasePath
    if (-not $basePathForUri.EndsWith("\")) {
        $basePathForUri += "\"
    }

    $baseUri = New-Object System.Uri($basePathForUri)
    $pathUri = New-Object System.Uri($resolvedPath)
    return ([System.Uri]::UnescapeDataString($baseUri.MakeRelativeUri($pathUri).ToString())).Replace("\", "/")
}

function Read-PbiJsonFile {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path $Path)) {
        throw "JSON file not found: $Path"
    }

    return (ConvertFrom-PbiJsonText -Text (Get-Content $Path -Raw))
}

function Write-PbiJsonFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)]$InputObject
    )

    $json = ConvertTo-PbiJsonText -InputObject $InputObject
    Write-PbiUtf8File -Path $Path -Content $json
}

function Invoke-PbiFileWriteWithRetry {
    param(
        [Parameter(Mandatory = $true)][scriptblock]$Action,
        [int]$MaxAttempts = 5,
        [int]$InitialDelayMilliseconds = 80
    )

    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        try {
            & $Action
            return
        }
        catch [System.IO.IOException] {
            if ($attempt -eq $MaxAttempts) {
                throw
            }
        }
        catch [System.UnauthorizedAccessException] {
            if ($attempt -eq $MaxAttempts) {
                throw
            }
        }

        Start-Sleep -Milliseconds ($InitialDelayMilliseconds * $attempt)
    }
}

function Write-PbiUtf8File {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [AllowNull()][string]$Content
    )

    $parentPath = Split-Path $Path -Parent
    if ($parentPath) {
        Ensure-PbiDirectory -Path $parentPath
    }

    $encoding = New-Object System.Text.UTF8Encoding($false)
    Invoke-PbiFileWriteWithRetry -Action {
        [System.IO.File]::WriteAllText($Path, [string]$Content, $encoding)
    }
}

function Add-PbiUtf8Line {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [AllowNull()][string]$Content
    )

    $parentPath = Split-Path $Path -Parent
    if ($parentPath) {
        Ensure-PbiDirectory -Path $parentPath
    }

    $encoding = New-Object System.Text.UTF8Encoding($false)
    Invoke-PbiFileWriteWithRetry -Action {
        [System.IO.File]::AppendAllText($Path, ([string]$Content + [Environment]::NewLine), $encoding)
    }
}

function Ensure-PbiDirectory {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Compare-PbiVersion {
    param(
        [Parameter(Mandatory = $true)][string]$LeftVersion,
        [Parameter(Mandatory = $true)][string]$RightVersion
    )

    $left = [System.Version]::Parse($LeftVersion)
    $right = [System.Version]::Parse($RightVersion)
    return $left.CompareTo($right)
}

function Get-PbiUtcTimestamp {
    return (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
}

function Get-PbiTimestampKey {
    return (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssfffZ")
}

function Get-PbiPathSizeBytes {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path $Path)) {
        return 0L
    }

    $item = Get-Item $Path
    if (-not $item.PSIsContainer) {
        return [int64]$item.Length
    }

    return [int64](
        Get-ChildItem -Path $item.FullName -Recurse -File -ErrorAction SilentlyContinue |
            Measure-Object -Property Length -Sum |
            Select-Object -ExpandProperty Sum
    )
}

Export-ModuleMember -Function Get-PbiInstallerWorkspaceRoot, ConvertFrom-PbiJsonText, ConvertTo-PbiJsonText, Resolve-PbiPath, Get-PbiRelativePath, Read-PbiJsonFile, Write-PbiJsonFile, Write-PbiUtf8File, Add-PbiUtf8Line, Ensure-PbiDirectory, Compare-PbiVersion, Get-PbiUtcTimestamp, Get-PbiTimestampKey, Get-PbiPathSizeBytes
