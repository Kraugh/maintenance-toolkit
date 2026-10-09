function Save-MTOemStatus {
    param([Parameter(Mandatory)][object]$Status)

    $Path = Join-Path $env:MT_SESSION_DIR "oem-status.json"
    $Status | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $Path -Encoding UTF8
    $env:MT_OEM_STATUS_PATH = $Path
}

# Only completed, present and recent points may protect an OEM operation.
function Get-MTRestorePointDate {
    param([Parameter(Mandatory)][object]$Point)
    if ($Point.CreationTime -is [datetime]) { return [datetime]$Point.CreationTime }
    return [Management.ManagementDateTimeConverter]::ToDateTime([string]$Point.CreationTime)
}

function Get-MTRecentRestorePoints {
    param([int]$ReuseWindowHours = 24)
    $Now = Get-Date
    return @(
        Get-ComputerRestorePoint -ErrorAction Stop | Where-Object {
            try {
                $Created = Get-MTRestorePointDate -Point $_
                [int]$_.EventType -eq 100 -and
                $Created -ge $Now.AddHours(-$ReuseWindowHours) -and $Created -le $Now
            }
            catch { $false }
        } | Sort-Object SequenceNumber -Descending
    )
}

function Save-MTVerifiedRestorePoint {
    param([object]$Point, [string]$MarkerPath, [bool]$Created)
    $Marker = [pscustomobject]@{
        description = [string]$Point.Description
        sequenceNumber = [int]$Point.SequenceNumber
        createdAt = (Get-MTRestorePointDate -Point $Point).ToString("o")
    }
    $Marker | ConvertTo-Json | Set-Content -LiteralPath $MarkerPath -Encoding UTF8
    $Key = if ($Created) { "OEM_RESTORE_CREATED" } else { "OEM_RESTORE_REUSED" }
    Write-Ok (Get-MTRuntimeText $Key @($Marker.description)) "OEM"
    return $Marker
}

function Get-MTVerifiedRestorePoint {
    param([Parameter(Mandatory)][string]$Manufacturer)

    $VerificationTimeoutSeconds = 90
    $MarkerPath = Join-Path $env:MT_SESSION_DIR "restore-point.json"
    try {
        $RecentPoints = @(Get-MTRecentRestorePoints)
        if (Test-Path -LiteralPath $MarkerPath -PathType Leaf) {
            $Marker = $null
            try {
                $Marker = Get-Content -LiteralPath $MarkerPath -Raw -Encoding UTF8 | ConvertFrom-Json
            }
            catch { $Marker = $null }
            if ($null -ne $Marker -and
                $null -ne $Marker.PSObject.Properties["sequenceNumber"] -and
                $null -ne $Marker.PSObject.Properties["description"]) {
                $MarkedPoint = $RecentPoints | Where-Object {
                    $_.SequenceNumber -eq $Marker.sequenceNumber -and
                    $_.Description -eq $Marker.description
                } | Select-Object -First 1
                if ($null -ne $MarkedPoint) {
                    return Save-MTVerifiedRestorePoint -Point $MarkedPoint -MarkerPath $MarkerPath -Created $false
                }
            }
        }
        # A recent Windows/vendor point also satisfies the existing 24-hour safeguard.
        # Do not change SystemRestorePointCreationFrequency to bypass Windows policy.
        if ($RecentPoints.Count -gt 0) {
            return Save-MTVerifiedRestorePoint -Point $RecentPoints[0] -MarkerPath $MarkerPath -Created $false
        }

        $Version = if ([string]::IsNullOrWhiteSpace($env:MT_VERSION)) { "unknown" } else { $env:MT_VERSION }
        $Description = "Maintenance Toolkit $Version - Before $Manufacturer updates - " +
            (Get-Date -Format "yyyy-MM-dd HH-mm-ss") + " - " + [guid]::NewGuid().ToString("N")
        Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction Stop
        Checkpoint-Computer -Description $Description -RestorePointType MODIFY_SETTINGS -ErrorAction Stop

        $Deadline = (Get-Date).AddSeconds($VerificationTimeoutSeconds)
        do {
            $RecentPoints = @(Get-MTRecentRestorePoints)
            $Point = $RecentPoints | Where-Object Description -eq $Description | Select-Object -First 1
            if ($null -ne $Point) {
                return Save-MTVerifiedRestorePoint -Point $Point -MarkerPath $MarkerPath -Created $true
            }
            # Windows may suppress creation if another application just created a point.
            if ($RecentPoints.Count -gt 0) {
                return Save-MTVerifiedRestorePoint -Point $RecentPoints[0] -MarkerPath $MarkerPath -Created $false
            }
            if ((Get-Date) -ge $Deadline) { break }
            Start-Sleep -Seconds 5
        } while ($true)
        throw (Get-MTRuntimeText "RESTORE_VERIFY_FAILED")
    }
    catch {
        throw (Get-MTRuntimeText "OEM_RESTORE_FAILED" @($_.Exception.Message))
    }
}

function Test-MTPendingReboot {
    $Paths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"
    )

    if (@($Paths | Where-Object { Test-Path -LiteralPath $_ }).Count -gt 0) {
        return $true
    }

    $SessionManager = Get-ItemProperty `
        "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" `
        -Name PendingFileRenameOperations `
        -ErrorAction SilentlyContinue

    return $null -ne $SessionManager.PendingFileRenameOperations
}

function Test-MTHpSignature {
    param([Parameter(Mandatory)][string]$Path)

    $Signature = Get-AuthenticodeSignature -LiteralPath $Path
    return (
        $Signature.Status -eq "Valid" -and
        $null -ne $Signature.SignerCertificate -and
        $Signature.SignerCertificate.Subject -match "(?:^|,\s*)O=HP Inc\."
    )
}

function Get-MTHpImageAssistant {
    $Version = "5.3.7"
    $ManagedRoot = Join-Path $env:ProgramData "Kraugh\MaintenanceToolkit\Tools\HPIA"
    $ManagedExecutable = Join-Path $ManagedRoot "$Version\HPImageAssistant.exe"
    $Candidates = @(
        $ManagedExecutable,
        "$env:ProgramFiles\HP\HPIA\HPImageAssistant.exe",
        "${env:ProgramFiles(x86)}\HP\HPIA\HPImageAssistant.exe",
        "$env:ProgramFiles\HP\HP Image Assistant\HPImageAssistant.exe"
    )

    $Existing = $Candidates |
        Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
        Select-Object -First 1

    if ($Existing) {
        if (-not (Test-MTHpSignature -Path $Existing)) {
            throw (Get-MTRuntimeText "OEM_TOOL_SIGNATURE_INVALID")
        }
        return $Existing
    }

    Write-Main (Get-MTRuntimeText "OEM_HP_DOWNLOAD" @($Version))
    $Staging = Join-Path $ManagedRoot "Staging"
    $Package = Join-Path $Staging "hp-hpia-$Version.exe"
    New-Item -ItemType Directory -Path $Staging -Force | Out-Null
    New-Item -ItemType Directory -Path (Split-Path $ManagedExecutable -Parent) -Force |
        Out-Null

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest `
        -Uri "https://hpia.hpcloud.hp.com/downloads/hpia/hp-hpia-$Version.exe" `
        -OutFile $Package `
        -UseBasicParsing `
        -TimeoutSec 300 `
        -ErrorAction Stop

    if (-not (Test-MTHpSignature -Path $Package)) {
        throw (Get-MTRuntimeText "OEM_TOOL_SIGNATURE_INVALID")
    }

    $null = Invoke-LoggedProcess `
        -FilePath $Package `
        -ArgumentList @(
            "-s",
            "-e",
            "-f",
            (Split-Path $ManagedExecutable -Parent)
        ) `
        -Label "HP Image Assistant extraction" `
        -Module "OEM" `
        -SuccessCodes @(0, 1168) `
        -TimeoutSeconds 300

    if (
        -not (Test-Path -LiteralPath $ManagedExecutable -PathType Leaf) -or
        -not (Test-MTHpSignature -Path $ManagedExecutable)
    ) {
        throw (Get-MTRuntimeText "OEM_TOOL_SIGNATURE_INVALID")
    }

    Write-Ok (Get-MTRuntimeText "OEM_HP_READY" @($Version)) "OEM"
    return $ManagedExecutable
}

function Invoke-MTHpia {
    param(
        [Parameter(Mandatory)][string]$Executable,
        [Parameter(Mandatory)][string]$Action,
        [string]$Category = "All",
        [string]$SPListPath,
        [int]$TimeoutSeconds = 3600
    )

    $OperationRoot = Join-Path $env:MT_SESSION_DIR (
        "HP-{0}-{1}" -f $Action, [guid]::NewGuid().ToString("N")
    )
    $ReportFolder = Join-Path $OperationRoot "Reports"
    $DownloadFolder = Join-Path $OperationRoot "Downloads"
    New-Item -ItemType Directory -Path $ReportFolder,$DownloadFolder -Force |
        Out-Null

    $Arguments = @(
        "/Operation:Analyze",
        "/Action:$Action",
        "/Category:$Category",
        "/Selection:All",
        "/Silent",
        "/ReportFolder:$ReportFolder",
        "/SoftPaqDownloadFolder:$DownloadFolder"
    )

    if (-not [string]::IsNullOrWhiteSpace($SPListPath)) {
        $Arguments += "/InstallType:AutoInstallable"
        $Arguments += "/SPList:$SPListPath"
        $Arguments += "/AutoCleanup"
    }

    $ExitCode = Invoke-LoggedProcess `
        -FilePath $Executable `
        -ArgumentList $Arguments `
        -Label "HP Image Assistant $Action" `
        -Module "OEM" `
        -SuccessCodes @(0, 256, 257, 3010, 3011) `
        -TimeoutSeconds $TimeoutSeconds

    $JsonPath = Get-ChildItem -LiteralPath $ReportFolder -Filter "*.json" -File `
        -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    $Data = if ($null -ne $JsonPath) {
        Get-Content -LiteralPath $JsonPath.FullName -Raw -Encoding UTF8 |
            ConvertFrom-Json
    }
    else {
        $null
    }

    return [pscustomobject]@{
        ExitCode = [int]$ExitCode
        Root = $OperationRoot
        ReportFolder = $ReportFolder
        JsonPath = if ($null -ne $JsonPath) { $JsonPath.FullName } else { $null }
        Data = $Data
    }
}

function Get-MTHpiaRecommendations {
    param([AllowNull()][object]$Operation)

    if ($null -eq $Operation -or $null -eq $Operation.Data) {
        return @()
    }
    return @($Operation.Data.HPIA.Recommendations)
}

function Read-MTHpiaSuppressionCache {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return @()
    }

    try {
        return @(Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json)
    }
    catch {
        return @()
    }
}

function Write-MTHpiaSuppressionCache {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][object[]]$Entries
    )

    $Parent = Split-Path $Path -Parent
    New-Item -ItemType Directory -Path $Parent -Force | Out-Null
    @($Entries) | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Suspend-MTBitLockerForBiosUpdate {
    if (-not (Get-Command Get-BitLockerVolume -ErrorAction SilentlyContinue)) {
        return
    }

    $Volume = Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction Stop
    if ($Volume.ProtectionStatus -ne "On") {
        return
    }

    $RecoveryPassword = @(
        $Volume.KeyProtector |
            Where-Object KeyProtectorType -eq "RecoveryPassword"
    )
    if ($RecoveryPassword.Count -eq 0) {
        throw (Get-MTRuntimeText "OEM_HP_BIOS_BITLOCKER_BLOCKED")
    }

    Suspend-BitLocker -MountPoint $env:SystemDrive -RebootCount 1 -ErrorAction Stop |
        Out-Null
    Write-WarnLog (Get-MTRuntimeText "OEM_HP_BIOS_BITLOCKER_SUSPENDED") "OEM"
}
