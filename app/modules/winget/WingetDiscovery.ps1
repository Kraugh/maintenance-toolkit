# Winget discovery uses inbox Windows APIs; no PATH changes or bootstrap.
function Test-MTWingetExecutable {
    param([string]$Path, [switch]$RequireMicrosoftSignature)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
    if ($RequireMicrosoftSignature) {
        $Signature = Get-AuthenticodeSignature -LiteralPath $Path -ErrorAction Stop
        if ($Signature.Status -ne 'Valid' -or $null -eq $Signature.SignerCertificate -or
            $Signature.SignerCertificate.Subject -notmatch 'O=Microsoft Corporation(?:,|$)') { return $false }
    }
    $Process = New-Object System.Diagnostics.Process
    try {
        $Process.StartInfo.FileName = $Path
        $Process.StartInfo.Arguments = '--version'
        $Process.StartInfo.UseShellExecute = $false
        $Process.StartInfo.CreateNoWindow = $true
        $Process.StartInfo.RedirectStandardOutput = $true
        $Process.StartInfo.RedirectStandardError = $true
        if (-not $Process.Start()) { return $false }
        $OutputTask = $Process.StandardOutput.ReadToEndAsync()
        $ErrorTask = $Process.StandardError.ReadToEndAsync()
        if (-not $Process.WaitForExit(15000)) {
            $Process.Kill()
            $Process.WaitForExit()
            return $false
        }
        return ($Process.ExitCode -eq 0 -and $OutputTask.Result.Trim() -match '^v?\d+\.\d+')
    }
    finally { $Process.Dispose() }
}

function Get-MTWingetCandidates {
    $Architecture = if ($env:PROCESSOR_ARCHITEW6432) { $env:PROCESSOR_ARCHITEW6432 } else { $env:PROCESSOR_ARCHITECTURE }
    $Architecture = switch ($Architecture) { 'AMD64' {'x64'} 'ARM64' {'arm64'} default {'x86'} }
    $ProgramRoot = if ($env:ProgramW6432) { $env:ProgramW6432 } else { $env:ProgramFiles }
    $AppsRoot = Join-Path $ProgramRoot 'WindowsApps'
    $Candidates = @()
    # Querying all users is permitted under SYSTEM/elevation. Failure does not
    # prevent checking the protected installation directory directly.
    try {
        foreach ($Package in @(Get-AppxPackage -AllUsers -Name Microsoft.DesktopAppInstaller -ErrorAction Stop)) {
            if ([string]$Package.Architecture -ieq $Architecture -and $Package.InstallLocation) {
                $Candidates += [pscustomobject]@{ Source=(Join-Path $Package.InstallLocation 'winget.exe'); Version=[version]$Package.Version }
            }
        }
    } catch { }
    try {
        foreach ($Directory in @(Get-ChildItem -LiteralPath $AppsRoot -Directory -ErrorAction Stop)) {
            if ($Directory.Name -match ('^Microsoft\.DesktopAppInstaller_(\d+\.\d+\.\d+\.\d+)_' + $Architecture + '__8wekyb3d8bbwe$')) {
                $Candidates += [pscustomobject]@{ Source=(Join-Path $Directory.FullName 'winget.exe'); Version=[version]$Matches[1] }
            }
        }
    } catch { }
    # Only paths inside the protected WindowsApps root may be used as fallback.
    $Prefix = $AppsRoot.TrimEnd('\') + '\'
    $Candidates | Where-Object { $_.Source.StartsWith($Prefix, [StringComparison]::OrdinalIgnoreCase) } |
        Sort-Object Version -Descending | Sort-Object Source -Unique
}

function Get-WingetCommand {
    $Command = Get-Command winget.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($Command) {
        try { if (Test-MTWingetExecutable -Path $Command.Source) { return $Command } } catch { }
    }
    foreach ($Candidate in @(Get-MTWingetCandidates | Sort-Object Version -Descending)) {
        try {
            if (Test-MTWingetExecutable -Path $Candidate.Source -RequireMicrosoftSignature) { return $Candidate }
        } catch { }
    }
    return $null
}
