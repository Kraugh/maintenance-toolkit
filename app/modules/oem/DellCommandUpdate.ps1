function Test-MTDellSignature {
    param([Parameter(Mandatory)][string]$Path)

    $Signature = Get-AuthenticodeSignature -LiteralPath $Path
    return (
        $Signature.Status -eq "Valid" -and
        $null -ne $Signature.SignerCertificate -and
        $Signature.SignerCertificate.Subject -match "(?:^|,\s*)O=Dell Technologies Inc\."
    )
}

function Get-MTDellCommandUpdate {
    $Candidates = @(
        "$env:ProgramFiles\Dell\CommandUpdate\dcu-cli.exe",
        "${env:ProgramFiles(x86)}\Dell\CommandUpdate\dcu-cli.exe"
    )
    $Executable = $Candidates |
        Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
        Select-Object -First 1

    if (-not $Executable) { return $null }
    if (-not (Test-MTDellSignature -Path $Executable)) {
        throw (Get-MTRuntimeText "OEM_TOOL_SIGNATURE_INVALID")
    }
    return $Executable
}

function Get-MTDcuXmlValue {
    param(
        [Parameter(Mandatory)][System.Xml.XmlElement]$Node,
        [Parameter(Mandatory)][string[]]$Names
    )

    foreach ($Name in $Names) {
        if ($Node.HasAttribute($Name)) { return [string]$Node.GetAttribute($Name) }
        $LowerName = $Name.ToLowerInvariant()
        $Child = $Node.SelectSingleNode("./*[translate(local-name(), 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz')='$LowerName']")
        if ($null -ne $Child -and -not [string]::IsNullOrWhiteSpace($Child.InnerText)) {
            return [string]$Child.InnerText
        }
    }
    return $null
}

function ConvertFrom-MTDcuReport {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw (Get-MTRuntimeText "OEM_DELL_REPORT_MISSING")
    }

    [xml]$Report = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    $Nodes = @($Report.SelectNodes("/*[local-name()='updates']/*[local-name()='update']"))
    if ($Nodes.Count -eq 0) {
        $Nodes = @($Report.SelectNodes("//*[local-name()='update']"))
    }

    return @(
        foreach ($Node in $Nodes) {
            [pscustomobject][ordered]@{
                id = Get-MTDcuXmlValue -Node $Node -Names @("release", "releaseID", "releaseId", "id")
                name = Get-MTDcuXmlValue -Node $Node -Names @("name", "title", "packageName")
                type = Get-MTDcuXmlValue -Node $Node -Names @("type", "updateType", "category")
                currentVersion = Get-MTDcuXmlValue -Node $Node -Names @("currentVersion", "installedVersion")
                targetVersion = Get-MTDcuXmlValue -Node $Node -Names @("version", "targetVersion", "releaseVersion")
                severity = Get-MTDcuXmlValue -Node $Node -Names @("urgency", "severity", "criticality")
                rebootRequired = Get-MTDcuXmlValue -Node $Node -Names @("rebootRequired", "reboot")
            }
        }
    )
}

function Get-MTDcuEffectiveExitCode {
    param(
        [Parameter(Mandatory)][int]$ProcessExitCode,
        [Parameter(Mandatory)][string]$LogPath
    )

    if (-not (Test-Path -LiteralPath $LogPath -PathType Leaf)) {
        return $ProcessExitCode
    }

    $Matches = @(
        Select-String `
            -LiteralPath $LogPath `
            -Pattern "program exited with return code:\s*(-?\d+)" `
            -AllMatches `
            -ErrorAction SilentlyContinue |
            ForEach-Object { $_.Matches } |
            ForEach-Object { $_.Groups[1].Value }
    )
    if ($Matches.Count -eq 0) {
        return $ProcessExitCode
    }
    return [int]$Matches[-1]
}

function Invoke-MTDcuScan {
    param(
        [Parameter(Mandatory)][string]$Executable,
        [Parameter(Mandatory)][string]$UpdateType,
        [Parameter(Mandatory)][string]$Purpose
    )

    $Root = Join-Path $env:MT_SESSION_DIR ("Dell-{0}-{1}" -f $Purpose, [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $Root -Force | Out-Null
    $LogPath = Join-Path $Root "dcu-$Purpose.log"
    $ProcessExitCode = Invoke-LoggedProcess `
        -FilePath $Executable `
        -ArgumentList @(
            "/scan",
            "-updateType=$UpdateType",
            "-report=$Root",
            "-outputLog=$LogPath",
            "-silent"
        ) `
        -Label "Dell Command Update $Purpose scan" `
        -Module "OEM" `
        -SuccessCodes @(0, 500) `
        -TimeoutSeconds 1800

    $ExitCode = Get-MTDcuEffectiveExitCode `
        -ProcessExitCode $ProcessExitCode `
        -LogPath $LogPath

    if ($ExitCode -notin @(0, 500)) {
        throw (Get-MTRuntimeText "OEM_DELL_SCAN_FAILED" @($ExitCode))
    }

    $ReportPath = Join-Path $Root "DCUApplicableUpdates.xml"
    $Updates = if ($ExitCode -eq 500 -and -not (Test-Path -LiteralPath $ReportPath -PathType Leaf)) {
        @()
    }
    else {
        @(ConvertFrom-MTDcuReport -Path $ReportPath)
    }
    if ($ExitCode -eq 0 -and @($Updates).Count -eq 0) {
        throw (Get-MTRuntimeText "OEM_DELL_REPORT_INVALID")
    }
    return [pscustomobject]@{
        ExitCode = [int]$ExitCode
        Root = $Root
        ReportPath = $ReportPath
        LogPath = $LogPath
        Updates = $Updates
    }
}

function Invoke-MTDcuSafeUpdates {
    param([Parameter(Mandatory)][string]$Executable)

    $LogPath = Join-Path $env:MT_SESSION_DIR "dcu-apply-safe-updates.log"
    $ProcessExitCode = Invoke-LoggedProcess `
        -FilePath $Executable `
        -ArgumentList @(
            "/applyUpdates",
            "-updateType=firmware,driver,application,utility,others",
            "-reboot=disable",
            "-outputLog=$LogPath",
            "-silent"
        ) `
        -Label "Dell Command Update safe updates" `
        -Module "OEM" `
        -SuccessCodes @(0, 1, 500) `
        -TimeoutSeconds 7200

    return Get-MTDcuEffectiveExitCode `
        -ProcessExitCode $ProcessExitCode `
        -LogPath $LogPath
}
