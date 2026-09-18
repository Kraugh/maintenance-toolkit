function Save-MTOemStatus {
    param([Parameter(Mandatory)][object]$Status)

    $Path = Join-Path $env:MT_SESSION_DIR "oem-status.json"
    $Status | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $Path -Encoding UTF8
    $env:MT_OEM_STATUS_PATH = $Path
}

function Get-MTVerifiedRestorePoint {
    param([Parameter(Mandatory)][string]$Manufacturer)

    $MarkerPath = Join-Path $env:MT_SESSION_DIR "restore-point.json"
    if (Test-Path -LiteralPath $MarkerPath -PathType Leaf) {
        $Marker = Get-Content -LiteralPath $MarkerPath -Raw -Encoding UTF8 |
            ConvertFrom-Json
        Write-Ok (Get-MTRuntimeText "OEM_RESTORE_REUSED" @($Marker.description)) "OEM"
        return $Marker
    }

    $RecentPoint = Get-ComputerRestorePoint -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Description -like "Maintenance Toolkit*" -and
            [Management.ManagementDateTimeConverter]::ToDateTime($_.CreationTime) -ge (Get-Date).AddHours(-2)
        } |
        Sort-Object SequenceNumber -Descending |
        Select-Object -First 1

    if ($null -ne $RecentPoint) {
        $Marker = [pscustomobject]@{
            description = [string]$RecentPoint.Description
            sequenceNumber = [int]$RecentPoint.SequenceNumber
            createdAt = [Management.ManagementDateTimeConverter]::ToDateTime(
                $RecentPoint.CreationTime
            ).ToString("o")
        }
        $Marker | ConvertTo-Json | Set-Content -LiteralPath $MarkerPath -Encoding UTF8
        Write-Ok (Get-MTRuntimeText "OEM_RESTORE_REUSED" @($Marker.description)) "OEM"
        return $Marker
    }

    $Timestamp = Get-Date -Format "yyyy-MM-dd HH-mm-ss"
    $Version = if ([string]::IsNullOrWhiteSpace($env:MT_VERSION)) {
        "unknown"
    }
    else {
        $env:MT_VERSION
    }
    $Description = "Maintenance Toolkit $Version - Before $Manufacturer updates - $Timestamp"

    try {
        Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction Stop
        Checkpoint-Computer `
            -Description $Description `
            -RestorePointType MODIFY_SETTINGS `
            -ErrorAction Stop

        $Point = Get-ComputerRestorePoint -ErrorAction Stop |
            Where-Object Description -eq $Description |
            Sort-Object SequenceNumber -Descending |
            Select-Object -First 1

        if ($null -eq $Point) {
            throw (Get-MTRuntimeText "RESTORE_VERIFY_FAILED")
        }

        $Marker = [pscustomobject]@{
            description = $Description
            sequenceNumber = [int]$Point.SequenceNumber
            createdAt = (Get-Date).ToString("o")
        }
        $Marker | ConvertTo-Json | Set-Content -LiteralPath $MarkerPath -Encoding UTF8
        Write-Ok (Get-MTRuntimeText "OEM_RESTORE_CREATED" @($Description)) "OEM"
        return $Marker
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
