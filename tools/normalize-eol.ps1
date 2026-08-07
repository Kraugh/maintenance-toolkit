[CmdletBinding()]
param(
    [string]$ProjectRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ScriptPath = $MyInvocation.MyCommand.Path

    if ([string]::IsNullOrWhiteSpace($ScriptPath)) {
        throw 'Unable to resolve normalize-eol.ps1 script path.'
    }

    $ScriptDirectory = Split-Path -Parent $ScriptPath
    $ProjectRoot = Split-Path -Parent $ScriptDirectory
}

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)

$Utf8BomExtensions = @('.ps1')
$TextExtensions = @(
    '.ps1','.psm1','.psd1','.json','.md','.txt','.ini',
    '.yml','.yaml','.gitignore','.gitattributes'
)

function Test-MTBinaryFile {
    param([Parameter(Mandatory)][string]$Path)

    $Bytes = [System.IO.File]::ReadAllBytes($Path)

    foreach ($Byte in $Bytes) {
        if ($Byte -eq 0) {
            return $true
        }
    }

    return $false
}

$Files = Get-ChildItem `
    -LiteralPath $ProjectRoot `
    -File `
    -Recurse `
    -Force |
    Where-Object {
        $_.FullName -notmatch '[\\/]\.git[\\/]' -and
        $_.FullName -notmatch '[\\/]dist[\\/]' -and
        $_.FullName -notmatch '[\\/]logs[\\/]' -and
        $_.FullName -notmatch '[\\/]reports[\\/].+\.(txt|json|html|zip)$'
    }

$Changed = 0

foreach ($File in $Files) {
    $Name = $File.Name.ToLowerInvariant()
    $Extension = $File.Extension.ToLowerInvariant()

    $IsSpecialText = @('.gitignore','.gitattributes','license') -contains $Name
    $IsDisabledPowerShell = $Name.EndsWith('.ps1.disabled')
    $IsWindowsLauncher = @('.bat','.cmd') -contains $Extension

    if (
        -not $IsSpecialText -and
        -not $IsDisabledPowerShell -and
        -not $IsWindowsLauncher -and
        $TextExtensions -notcontains $Extension
    ) {
        continue
    }

    if (Test-MTBinaryFile -Path $File.FullName) {
        continue
    }

    $Bytes = [System.IO.File]::ReadAllBytes($File.FullName)
    $HasBom = (
        $Bytes.Length -ge 3 -and
        $Bytes[0] -eq 0xEF -and
        $Bytes[1] -eq 0xBB -and
        $Bytes[2] -eq 0xBF
    )

    $Text = if ($HasBom) {
        [System.Text.Encoding]::UTF8.GetString($Bytes, 3, $Bytes.Length - 3)
    }
    else {
        [System.Text.Encoding]::UTF8.GetString($Bytes)
    }

    $Normalized = $Text -replace "`r`n", "`n" -replace "`r", "`n"

    if ($IsWindowsLauncher) {
        $Normalized = $Normalized -replace "`n", "`r`n"
    }

    $NeedsBom = (
        ($Utf8BomExtensions -contains $Extension) -or
        $IsDisabledPowerShell
    )

    $Encoding = New-Object System.Text.UTF8Encoding($false)
    $PayloadBytes = $Encoding.GetBytes($Normalized)

    if ($NeedsBom) {
        $Preamble = [byte[]](0xEF, 0xBB, 0xBF)
        $NewBytes = New-Object byte[] ($Preamble.Length + $PayloadBytes.Length)

        [System.Array]::Copy(
            $Preamble,
            0,
            $NewBytes,
            0,
            $Preamble.Length
        )

        [System.Array]::Copy(
            $PayloadBytes,
            0,
            $NewBytes,
            $Preamble.Length,
            $PayloadBytes.Length
        )
    }
    else {
        $NewBytes = $PayloadBytes
    }

    if (
        $Bytes.Length -ne $NewBytes.Length -or
        [Convert]::ToBase64String($Bytes) -ne
        [Convert]::ToBase64String($NewBytes)
    ) {
        [System.IO.File]::WriteAllBytes($File.FullName, $NewBytes)
        $Changed++
    }
}

Write-Host ("EOL normalization completed. Files changed: {0}" -f $Changed)
