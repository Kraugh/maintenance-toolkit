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

function Test-MTSystemIdentity {
    return [Security.Principal.WindowsIdentity]::GetCurrent().IsSystem
}

function Test-MTAuthenticodeOrganization {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$OrganizationPattern
    )

    $Signature = Get-AuthenticodeSignature -LiteralPath $Path
    return (
        $Signature.Status -eq "Valid" -and
        $null -ne $Signature.SignerCertificate -and
        $Signature.SignerCertificate.Subject -match $OrganizationPattern
    )
}

function Test-MTDotNetDesktopRuntime10 {
    $Roots = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    $MinimumVersion = [version]"10.0.8"
    return [bool](
        Get-ItemProperty -Path $Roots -ErrorAction SilentlyContinue |
            Where-Object {
                $DisplayNameProperty = $_.PSObject.Properties['DisplayName']
                $DisplayVersionProperty = $_.PSObject.Properties['DisplayVersion']
                $null -ne $DisplayNameProperty -and
                $null -ne $DisplayVersionProperty -and
                $DisplayNameProperty.Value -match '^Microsoft Windows Desktop Runtime(?: -)? 10\.0' -and
                -not [string]::IsNullOrWhiteSpace([string]$DisplayVersionProperty.Value)
            } |
            Where-Object {
                try { [version]$_.PSObject.Properties['DisplayVersion'].Value -ge $MinimumVersion }
                catch { $false }
            } |
            Select-Object -First 1
    )
}

function Install-MTDotNetDesktopRuntime10 {
    if (Test-MTDotNetDesktopRuntime10) { return }

    $RuntimePath = Join-Path $env:MT_SESSION_DIR "windowsdesktop-runtime-10-x64.exe"
    Write-Main (Get-MTRuntimeText "OEM_DELL_DOTNET_BOOTSTRAP_START")
    try {
        Invoke-WebRequest `
            -Uri "https://aka.ms/dotnet/10.0/windowsdesktop-runtime-win-x64.exe" `
            -OutFile $RuntimePath `
            -UseBasicParsing `
            -ErrorAction Stop
    }
    catch {
        throw (Get-MTRuntimeText "OEM_DELL_DOTNET_DOWNLOAD_FAILED" @($_.Exception.Message))
    }

    if (-not (Test-MTAuthenticodeOrganization `
        -Path $RuntimePath `
        -OrganizationPattern '(?:^|,\s*)O=Microsoft Corporation(?:,|$)')) {
        throw (Get-MTRuntimeText "OEM_DELL_DOTNET_SIGNATURE_INVALID")
    }

    $ExitCode = Invoke-LoggedProcess `
        -FilePath $RuntimePath `
        -ArgumentList @("/install", "/quiet", "/norestart") `
        -Label (Get-MTRuntimeText "OEM_DELL_DOTNET_BOOTSTRAP_LABEL") `
        -Module "OEM" `
        -SuccessCodes @(0, 3010) `
        -TimeoutSeconds 900

    if ($ExitCode -notin @(0, 3010) -or -not (Test-MTDotNetDesktopRuntime10)) {
        throw (Get-MTRuntimeText "OEM_DELL_DOTNET_BOOTSTRAP_FAILED" @($ExitCode))
    }
}

function Install-MTDellCommandUpdateDirect {
    # Dell Command Update Classic 5.7.2, published by Dell on 11 Sep 2026.
    # Pinning URL and hash makes the unattended bootstrap deterministic.
    $InstallerUrl = "https://dl.dell.com/FOLDER15013494M/2/Dell-Command-Update-for-Win32_WYJ59_WIN64_5.7.2_A00.EXE"
    $ExpectedSha256 = "5C20E1A352FDBC0A9759504DB37C7B8C694F4024F5F5313C5130C0959BE8D484"
    $InstallerPath = Join-Path $env:MT_SESSION_DIR "DellCommandUpdate-5.7.2-A00.exe"

    Install-MTDotNetDesktopRuntime10
    Write-Main (Get-MTRuntimeText "OEM_DELL_BOOTSTRAP_DIRECT_START")
    try {
        Invoke-WebRequest `
            -Uri $InstallerUrl `
            -OutFile $InstallerPath `
            -UserAgent "DellCommandUpdate/5.7.2" `
            -UseBasicParsing `
            -ErrorAction Stop
    }
    catch {
        throw (Get-MTRuntimeText "OEM_DELL_BOOTSTRAP_DOWNLOAD_FAILED" @($_.Exception.Message))
    }

    $ActualSha256 = (Get-FileHash -LiteralPath $InstallerPath -Algorithm SHA256).Hash
    if ($ActualSha256 -ne $ExpectedSha256) {
        throw (Get-MTRuntimeText "OEM_DELL_BOOTSTRAP_HASH_INVALID")
    }
    if (-not (Test-MTDellSignature -Path $InstallerPath)) {
        throw (Get-MTRuntimeText "OEM_TOOL_SIGNATURE_INVALID")
    }

    $ExitCode = Invoke-LoggedProcess `
        -FilePath $InstallerPath `
        -ArgumentList @(
            "/passthrough",
            "/S",
            "/V/quiet",
            "/V/norestart"
        ) `
        -Label (Get-MTRuntimeText "OEM_DELL_BOOTSTRAP_LABEL") `
        -Module "OEM" `
        -SuccessCodes @(0, 2) `
        -TimeoutSeconds 900

    if ($ExitCode -notin @(0, 2)) {
        throw (Get-MTRuntimeText "OEM_DELL_BOOTSTRAP_FAILED" @($ExitCode))
    }
    if ($ExitCode -eq 2) {
        throw (Get-MTRuntimeText "OEM_DELL_BOOTSTRAP_REBOOT_REQUIRED")
    }
}

function Install-MTDellCommandUpdate {
    $Winget = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($null -ne $Winget -and -not (Test-MTSystemIdentity)) {
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
    }
    else {
        Install-MTDellCommandUpdateDirect
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
        Add-Log "INFO" (Get-MTRuntimeText "OEM_DELL_EXIT_NATIVE_MISSING" @($ProcessExitCode)) "OEM"
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
        Add-Log "INFO" (Get-MTRuntimeText "OEM_DELL_EXIT_NATIVE_MISSING" @($ProcessExitCode)) "OEM"
        return $ProcessExitCode
    }
    $NativeExitCode = [int]$Matches[-1]
    Add-Log "INFO" (Get-MTRuntimeText "OEM_DELL_EXIT_EVIDENCE" @($ProcessExitCode, $NativeExitCode)) "OEM"
    # A runner failure/timeout must never be hidden by a successful native log.
    if ($ProcessExitCode -notin @(0, 1, 5, 500)) { return $ProcessExitCode }
    return $NativeExitCode
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

function New-MTDcuWorkDirectory {
    $WorkBase = Join-Path $env:SystemDrive "Kraugh-MT-Work"
    $WorkRoot = Join-Path $WorkBase ("DCU-{0}" -f [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $WorkRoot -Force | Out-Null
    return $WorkRoot
}

function Complete-MTDcuWorkDirectory {
    param(
        [Parameter(Mandatory)][string]$WorkRoot,
        [Parameter(Mandatory)][string]$PersistentRoot
    )

    if (-not (Test-Path -LiteralPath $WorkRoot -PathType Container)) { return }

    New-Item -ItemType Directory -Path $PersistentRoot -Force | Out-Null
    Get-ChildItem -LiteralPath $WorkRoot -Force | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $PersistentRoot -Recurse -Force
    }
    Remove-Item -LiteralPath $WorkRoot -Recurse -Force

    $WorkBase = Split-Path -Path $WorkRoot -Parent
    if (
        (Test-Path -LiteralPath $WorkBase -PathType Container) -and
        @(Get-ChildItem -LiteralPath $WorkBase -Force).Count -eq 0
    ) {
        Remove-Item -LiteralPath $WorkBase -Force
    }
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
    $RunName = "Dell-{0}-{1}" -f $Purpose, [guid]::NewGuid().ToString("N")
    $PersistentRoot = Join-Path $env:MT_SESSION_DIR $RunName
    $WorkRoot = New-MTDcuWorkDirectory
    $LogPath = Join-Path $WorkRoot "dcu-$Purpose.log"
    # DCU 5.7.x treats -report as a directory even when the supplied value
    # ends in .xml, then creates DCUApplicableUpdates.xml inside it.
    $ReportDirectory = Join-Path $WorkRoot "report"
    New-Item -ItemType Directory -Path $ReportDirectory -Force | Out-Null
    $ReportPath = Join-Path $ReportDirectory "DCUApplicableUpdates.xml"
    $VerificationDeadline = (Get-Date).AddSeconds(900)

    try {
        do {
            $ProcessExitCode = Invoke-LoggedProcess `
                -FilePath $Executable `
                -ArgumentList @(
                    "/scan",
                    "-updateType=$UpdateType",
                    "-report=$ReportDirectory",
                    "-outputLog=$LogPath",
                    "-silent"
                ) `
                -Label (Get-MTRuntimeText $LabelKey) `
                -Module "OEM" `
                -ProcessOutcomeOnly `
                -SuccessCodes @(0, 5, 500) `
                -TimeoutSeconds 1800

            $ExitCode = Get-MTDcuEffectiveExitCode `
                -ProcessExitCode $ProcessExitCode `
                -LogPath $LogPath

            if (
                $Purpose -ne "verification" -or
                (Test-Path -LiteralPath $ReportPath -PathType Leaf) -or
                $ExitCode -eq 5 -or
                $ExitCode -eq 500 -or
                (Get-Date) -ge $VerificationDeadline
            ) {
                break
            }

            Write-Main (Get-MTRuntimeText "OEM_DELL_SELF_UPDATE_WAIT")
            Start-Sleep -Seconds 15
        } while ($true)

        if ($ExitCode -notin @(0, 5, 500)) {
            throw (Get-MTRuntimeText "OEM_DELL_SCAN_FAILED" @($ExitCode))
        }

        $Updates = if ($ExitCode -in @(5, 500) -and -not (Test-Path -LiteralPath $ReportPath -PathType Leaf)) {
            @()
        }
        else {
            @(ConvertFrom-MTDcuReport -Path $ReportPath)
        }
        if ($ExitCode -eq 0 -and @($Updates).Count -eq 0) {
            throw (Get-MTRuntimeText "OEM_DELL_REPORT_INVALID")
        }
        $PersistentReportPath = Join-Path $PersistentRoot "report\DCUApplicableUpdates.xml"
        $PersistentLogPath = Join-Path $PersistentRoot "dcu-$Purpose.log"
        return [pscustomobject]@{
            ExitCode = [int]$ExitCode
            ProcessExitCode = [int]$ProcessExitCode
            Root = $PersistentRoot
            ReportPath = $PersistentReportPath
            LogPath = $PersistentLogPath
            Updates = $Updates
            RebootRequired = [bool]($ExitCode -eq 5)
        }
    }
    finally {
        Complete-MTDcuWorkDirectory -WorkRoot $WorkRoot -PersistentRoot $PersistentRoot
    }
}

function Invoke-MTDcuSafeUpdates {
    param([Parameter(Mandatory)][string]$Executable)

    $PreviousVersion = [string](Get-Item -LiteralPath $Executable).VersionInfo.FileVersion
    $WorkRoot = New-MTDcuWorkDirectory
    $PersistentRoot = Join-Path $env:MT_SESSION_DIR ("Dell-apply-{0}" -f [guid]::NewGuid().ToString("N"))
    $LogPath = Join-Path $WorkRoot "dcu-apply-safe-updates.log"

    try {
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
            -ProcessOutcomeOnly `
            -SuccessCodes @(0, 1, 5, 500) `
            -TimeoutSeconds 7200

        $ExitCode = Get-MTDcuEffectiveExitCode `
            -ProcessExitCode $ProcessExitCode `
            -LogPath $LogPath

        $PersistentLogPath = Join-Path $PersistentRoot "dcu-apply-safe-updates.log"
        return [pscustomobject]@{
            ExitCode = [int]$ExitCode
            ProcessExitCode = [int]$ProcessExitCode
            LogPath = $PersistentLogPath
            SelfUpdateStarted = [bool](Test-MTDcuSelfUpdateStarted -LogPath $LogPath)
            PreviousToolVersion = $PreviousVersion
            Evidence = Get-MTDcuApplyEvidence -ExitCode $ExitCode -LogPath $LogPath
        }
    }
    finally {
        Complete-MTDcuWorkDirectory -WorkRoot $WorkRoot -PersistentRoot $PersistentRoot
    }
}

# Interpret only the log produced by this invocation, never shared service history.
function Get-MTDcuApplyEvidence {
    param([int]$ExitCode, [string]$LogPath)
    $Text = if (Test-Path -LiteralPath $LogPath -PathType Leaf) {
        Get-Content -LiteralPath $LogPath -Raw -ErrorAction Stop
    } else { '' }
    $Deferred = $Text -match '(?i)interrupted.*UserActivity|after UserActivity Completes'
    $Outcome = if ($Deferred) { 'deferred_by_user_activity' }
        elseif ($ExitCode -eq 500) { 'no_applicable_updates' }
        elseif ($ExitCode -in @(1,5)) { 'restart_required' }
        elseif ($ExitCode -eq 0) { 'verification_required' }
        else { 'failed' }
    [pscustomobject]@{ Outcome=$Outcome; Deferred=$Deferred; ExitCode=$ExitCode }
}
