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

function Install-MTDellCommandUpdate {
    $Winget = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($null -eq $Winget) {
        throw (Get-MTRuntimeText "OEM_DELL_BOOTSTRAP_WINGET_MISSING")
    }

    Write-Main (Get-MTRuntimeText "OEM_DELL_BOOTSTRAP_START")
    $ExitCode = Invoke-LoggedProcess `
        -FilePath $Winget.Source `
        -ArgumentList @(
            "install",
            "--id", "Dell.CommandUpdate",
            "--exact",
            "--source", "winget",
            "--silent",
            "--accept-package-agreements",
            "--accept-source-agreements",
            "--disable-interactivity"
        ) `
        -Label (Get-MTRuntimeText "OEM_DELL_BOOTSTRAP_LABEL") `
        -Module "OEM" `
        -SuccessCodes @(0) `
        -OutputEncoding "UTF8" `
        -TimeoutSeconds 900

    if ($ExitCode -ne 0) {
        throw (Get-MTRuntimeText "OEM_DELL_BOOTSTRAP_FAILED" @($ExitCode))
    }

    $Executable = Get-MTDellCommandUpdate
    if (-not $Executable) {
        throw (Get-MTRuntimeText "OEM_DELL_BOOTSTRAP_NOT_FOUND")
    }

    $Version = [string](Get-Item -LiteralPath $Executable).VersionInfo.FileVersion
    Write-Ok (Get-MTRuntimeText "OEM_DELL_BOOTSTRAP_COMPLETED" @($Version)) "OEM"
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

function Test-MTDcuSelfUpdateStarted {
    param([Parameter(Mandatory)][string]$LogPath)

    if (-not (Test-Path -LiteralPath $LogPath -PathType Leaf)) {
        return $false
    }

    return [bool](
        Select-String `
            -LiteralPath $LogPath `
            -Pattern "performing a self update|pending self-update installation" `
            -Quiet `
            -ErrorAction SilentlyContinue
    )
}

function Wait-MTDcuSelfUpdate {
    param(
        [Parameter(Mandatory)][string]$PreviousVersion,
        [ValidateRange(30, 3600)][int]$TimeoutSeconds = 900
    )

    $Deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        $Installers = @(
            Get-Process -Name "DellCommandUpdateApp_Setup" -ErrorAction SilentlyContinue
        )
        $Executable = $null
        try {
            $Executable = Get-MTDellCommandUpdate
        }
        catch {
            $Executable = $null
        }

        if ($Executable) {
            $CurrentVersion = [string](Get-Item -LiteralPath $Executable).VersionInfo.FileVersion
            if (
                $Installers.Count -eq 0 -and
                -not [string]::IsNullOrWhiteSpace($CurrentVersion) -and
                $CurrentVersion -ne $PreviousVersion
            ) {
                Start-Sleep -Seconds 5
                $RemainingInstallers = @(
                    Get-Process -Name "DellCommandUpdateApp_Setup" -ErrorAction SilentlyContinue
                )
                if (
                    $RemainingInstallers.Count -eq 0 -and
                    (Test-Path -LiteralPath $Executable -PathType Leaf) -and
                    (Test-MTDellSignature -Path $Executable)
                ) {
                    return [pscustomobject]@{
                        Executable = $Executable
                        Version = [string](Get-Item -LiteralPath $Executable).VersionInfo.FileVersion
                    }
                }
            }
        }

        Start-Sleep -Seconds 5
    } while ((Get-Date) -lt $Deadline)

    throw (Get-MTRuntimeText "OEM_DELL_SELF_UPDATE_TIMEOUT" @($TimeoutSeconds))
}

function Invoke-MTDcuScan {
    param(
        [Parameter(Mandatory)][string]$Executable,
        [Parameter(Mandatory)][string]$UpdateType,
        [Parameter(Mandatory)][string]$Purpose
    )

    $LabelKey = switch ($Purpose) {
        "bios" { "OEM_DELL_SCAN_BIOS" }
        "safe" { "OEM_DELL_SCAN_SAFE" }
        "verification" { "OEM_DELL_SCAN_VERIFICATION" }
        default { throw "Unsupported Dell scan purpose: $Purpose" }
    }
    $Root = Join-Path $env:MT_SESSION_DIR ("Dell-{0}-{1}" -f $Purpose, [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $Root -Force | Out-Null
    $LogPath = Join-Path $Root "dcu-$Purpose.log"
    $ReportPath = Join-Path $Root "DCUApplicableUpdates.xml"
    $VerificationDeadline = (Get-Date).AddSeconds(900)

    do {
        $ProcessExitCode = Invoke-LoggedProcess `
            -FilePath $Executable `
            -ArgumentList @(
                "/scan",
                "-updateType=$UpdateType",
                "-report=$Root",
                "-outputLog=$LogPath",
                "-silent"
            ) `
            -Label (Get-MTRuntimeText $LabelKey) `
            -Module "OEM" `
            -SuccessCodes @(0, 500) `
            -TimeoutSeconds 1800

        $ExitCode = Get-MTDcuEffectiveExitCode `
            -ProcessExitCode $ProcessExitCode `
            -LogPath $LogPath

        if (
            $Purpose -ne "verification" -or
            (Test-Path -LiteralPath $ReportPath -PathType Leaf) -or
            $ExitCode -eq 500 -or
            (Get-Date) -ge $VerificationDeadline
        ) {
            break
        }

        Write-Main (Get-MTRuntimeText "OEM_DELL_SELF_UPDATE_WAIT")
        Start-Sleep -Seconds 15
    } while ($true)

    if ($ExitCode -notin @(0, 500)) {
        throw (Get-MTRuntimeText "OEM_DELL_SCAN_FAILED" @($ExitCode))
    }

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

    $PreviousVersion = [string](Get-Item -LiteralPath $Executable).VersionInfo.FileVersion
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
        -Label (Get-MTRuntimeText "OEM_DELL_APPLY_SAFE") `
        -Module "OEM" `
        -SuccessCodes @(0, 1, 500) `
        -TimeoutSeconds 7200

    $ExitCode = Get-MTDcuEffectiveExitCode `
        -ProcessExitCode $ProcessExitCode `
        -LogPath $LogPath

    return [pscustomobject]@{
        ExitCode = [int]$ExitCode
        LogPath = $LogPath
        SelfUpdateStarted = [bool](Test-MTDcuSelfUpdateStarted -LogPath $LogPath)
        PreviousToolVersion = $PreviousVersion
    }
}
