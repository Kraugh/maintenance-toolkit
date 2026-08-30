# Maintenance Toolkit 5.0 - Inventory Schema 1.0 collector
# Core collector only: no UI, no remote publishing, no report-file writer.
# Windows PowerShell 5.1 compatible.

Set-StrictMode -Version 2.0

function ConvertTo-MTInventoryIso8601 {
    param([object]$Value)

    if ($null -eq $Value) {
        return $null
    }

    try {
        return ([datetime]$Value).ToString("o")
    }
    catch {
        return $null
    }
}

function ConvertTo-MTInventoryCleanString {
    param([object]$Value)

    if ($null -eq $Value) {
        return $null
    }

    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text)) {
        return $null
    }

    return $text.Trim()
}

function ConvertTo-MTInventoryNullableBoolean {
    param([object]$Value)

    if ($null -eq $Value) {
        return $null
    }

    try {
        return [bool]$Value
    }
    catch {
        return $null
    }
}

function ConvertTo-MTInventoryUInt64OrNull {
    param([object]$Value)

    if ($null -eq $Value) {
        return $null
    }

    try {
        return [uint64]$Value
    }
    catch {
        return $null
    }
}

function New-MTInventoryError {
    param(
        [Parameter(Mandatory = $true)][string]$Code,
        [Parameter(Mandatory = $true)][string]$Source
    )

    return [ordered]@{
        code   = $Code
        source = $Source
    }
}

function Get-MTInventoryErrorCode {
    param([System.Management.Automation.ErrorRecord]$ErrorRecord)

    if ($null -eq $ErrorRecord) {
        return "query_failed"
    }

    $message = [string]$ErrorRecord.Exception.Message
    $fqid = [string]$ErrorRecord.FullyQualifiedErrorId

    if ($message -match '(?i)access.*denied|unauthorized|privileg|amministrat' -or
        $fqid -match '(?i)UnauthorizedAccess') {
        return "access_denied"
    }

    if ($fqid -match '(?i)CommandNotFound' -or $message -match '(?i)is not recognized|not found') {
        return "command_unavailable"
    }

    return "query_failed"
}

function New-MTInventorySection {
    param(
        [Parameter(Mandatory = $true)][scriptblock]$Collector,
        [Parameter(Mandatory = $true)][string]$Source,
        [object]$FallbackData = $null
    )

    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $data = & $Collector
        $watch.Stop()

        return [ordered]@{
            status     = "ok"
            durationMs = [int64]$watch.ElapsedMilliseconds
            errors     = @()
            data       = $data
        }
    }
    catch {
        $watch.Stop()

        return [ordered]@{
            status     = "error"
            durationMs = [int64]$watch.ElapsedMilliseconds
            errors     = @(
                New-MTInventoryError -Code (Get-MTInventoryErrorCode $_) -Source $Source
            )
            data       = $FallbackData
        }
    }
}

function New-MTInventoryPartialSection {
    param(
        [Parameter(Mandatory = $true)][object]$Data,
        [Parameter(Mandatory = $true)][long]$DurationMs,
        [object[]]$Errors
    )

    $safeErrors = @($Errors | Where-Object { $null -ne $_ })

    return [ordered]@{
        status     = if ($safeErrors.Count -gt 0) { "partial" } else { "ok" }
        durationMs = [int64]$DurationMs
        errors     = $safeErrors
        data       = $Data
    }
}

function ConvertTo-MTFirmwareType {
    param([uint32]$FirmwareType)

    switch ($FirmwareType) {
        1 { return "bios" }
        2 { return "uefi" }
        default { return "unknown" }
    }
}

function Get-MTFirmwareType {
    $nativeType = "MTInventoryNativeMethods" -as [type]

    if ($null -eq $nativeType) {
        Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public static class MTInventoryNativeMethods
{
    [DllImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool GetFirmwareType(out UInt32 firmwareType);
}
"@
    }

    [uint32]$value = 0
    $ok = [MTInventoryNativeMethods]::GetFirmwareType([ref]$value)
    if (-not $ok) {
        return "unknown"
    }

    return ConvertTo-MTFirmwareType -FirmwareType $value
}

function ConvertTo-MTMemoryType {
    param([object]$SmbiosMemoryType)

    if ($null -eq $SmbiosMemoryType) {
        return $null
    }

    switch ([int]$SmbiosMemoryType) {
        18 { return "ddr" }
        19 { return "ddr2" }
        20 { return "ddr2-fb-dimm" }
        24 { return "ddr3" }
        26 { return "ddr4" }
        30 { return "lpddr4" }
        34 { return "ddr5" }
        35 { return "lpddr5" }
        default { return $null }
    }
}

function ConvertTo-MTBusType {
    param([object]$Value)

    $text = ConvertTo-MTInventoryCleanString $Value
    if ($null -eq $text) {
        return $null
    }

    switch -Regex ($text.ToLowerInvariant()) {
        '^nvme$' { return "nvme" }
        '^sata$' { return "sata" }
        '^sas$'  { return "sas" }
        '^usb$'  { return "usb" }
        '^raid$' { return "raid" }
        '^scsi$' { return "scsi" }
        '^ata$'  { return "ata" }
        default  { return $text.ToLowerInvariant() }
    }
}

function ConvertTo-MTMediaType {
    param([object]$Value)

    $text = ConvertTo-MTInventoryCleanString $Value
    if ($null -eq $text) {
        return $null
    }

    switch -Regex ($text.ToLowerInvariant()) {
        'ssd|solid' { return "ssd" }
        'hdd|hard'  { return "hdd" }
        'scm'       { return "scm" }
        'unspecified|unknown' { return $null }
        default     { return $text.ToLowerInvariant() }
    }
}

function ConvertTo-MTNetworkFamily {
    param([object]$Address)

    $text = ConvertTo-MTInventoryCleanString $Address
    if ($null -eq $text) {
        return $null
    }

    if ($text -match ':') {
        return "ipv6"
    }

    return "ipv4"
}

function ConvertTo-MTNetworkType {
    param(
        [object]$PhysicalMediaType,
        [object]$Description,
        [bool]$IsVirtual
    )

    if ($IsVirtual) {
        return "virtual"
    }

    $media = ConvertTo-MTInventoryCleanString $PhysicalMediaType
    $desc = ConvertTo-MTInventoryCleanString $Description
    $haystack = "{0} {1}" -f $media, $desc

    if ($haystack -match '(?i)802\.11|wi-?fi|wireless') {
        return "wifi"
    }

    if ($haystack -match '(?i)bluetooth') {
        return "bluetooth"
    }

    if ($haystack -match '(?i)ethernet|802\.3') {
        return "ethernet"
    }

    return $null
}

function ConvertTo-MTDsregBoolean {
    param([object]$Value)

    $text = ConvertTo-MTInventoryCleanString $Value
    if ($null -eq $text) {
        return $null
    }

    switch ($text.ToUpperInvariant()) {
        "YES" { return $true }
        "NO"  { return $false }
        default { return $null }
    }
}

function Get-MTDsregValue {
    param(
        [string[]]$Lines,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $escaped = [regex]::Escape($Name)
    $line = $Lines | Where-Object { $_ -match ("^\s*" + $escaped + "\s*:") } | Select-Object -First 1
    if ($null -eq $line) {
        return $null
    }

    return ConvertTo-MTInventoryCleanString (($line -split ":", 2)[1])
}

function Get-MTInventoryPropertyValue {
    param(
        [object]$InputObject,
        [Parameter(Mandatory = $true)][string]$Name
    )

    if ($null -eq $InputObject) {
        return $null
    }

    $property = $InputObject.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }

    return $property.Value
}

function Get-MTClassicSoftwareInventory {
    $sources = @(
        [pscustomobject]@{
            Path  = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
            Scope = "machine"
            View  = "64-bit"
        },
        [pscustomobject]@{
            Path  = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
            Scope = "machine"
            View  = "32-bit"
        },
        [pscustomobject]@{
            Path  = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
            Scope = "user"
            View  = "native"
        }
    )

    $result = New-Object System.Collections.Generic.List[object]

    foreach ($source in $sources) {
        $items = @(Get-ItemProperty -Path $source.Path -ErrorAction SilentlyContinue)

        foreach ($item in $items) {
            $displayName = ConvertTo-MTInventoryCleanString (Get-MTInventoryPropertyValue -InputObject $item -Name "DisplayName")
            if ($null -eq $displayName) {
                continue
            }

            $result.Add([ordered]@{
                name             = $displayName
                version          = ConvertTo-MTInventoryCleanString (Get-MTInventoryPropertyValue -InputObject $item -Name "DisplayVersion")
                publisher        = ConvertTo-MTInventoryCleanString (Get-MTInventoryPropertyValue -InputObject $item -Name "Publisher")
                scope            = $source.Scope
                registryView     = $source.View
                installDate      = ConvertTo-MTInventoryCleanString (Get-MTInventoryPropertyValue -InputObject $item -Name "InstallDate")
                windowsInstaller = ConvertTo-MTInventoryNullableBoolean (Get-MTInventoryPropertyValue -InputObject $item -Name "WindowsInstaller")
                systemComponent  = ConvertTo-MTInventoryNullableBoolean (Get-MTInventoryPropertyValue -InputObject $item -Name "SystemComponent")
            })
        }
    }

    return $result.ToArray()
}

function Get-MTAppxInventory {
    $packages = @(Get-AppxPackage -AllUsers -ErrorAction Stop)

    return @($packages | ForEach-Object {
        [ordered]@{
            name              = ConvertTo-MTInventoryCleanString $_.Name
            version           = if ($null -ne $_.Version) { [string]$_.Version } else { $null }
            architecture      = ConvertTo-MTInventoryCleanString ([string]$_.Architecture)
            isFramework       = ConvertTo-MTInventoryNullableBoolean $_.IsFramework
            isResourcePackage = ConvertTo-MTInventoryNullableBoolean $_.IsResourcePackage
        }
    })
}

function Get-MTInventorySnapshot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$CollectorVersion,
        [hashtable]$MaintenanceData
    )

    $overallWatch = [System.Diagnostics.Stopwatch]::StartNew()
    $collectedAt = (Get-Date).ToString("o")
    $snapshotId = [guid]::NewGuid().ToString()

    # Shared lightweight objects. Individual section failures remain isolated.
    $shared = @{}

    $device = New-MTInventorySection -Source "device" -FallbackData ([ordered]@{
        hostname = $env:COMPUTERNAME
        manufacturer = $null
        model = $null
        systemUuid = $null
        biosSerialNumber = $null
        assetTag = $null
        chassis = [ordered]@{ serialNumber = $null; types = @() }
        baseboard = [ordered]@{ manufacturer = $null; product = $null; serialNumber = $null }
    }) -Collector {
        $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
        $csp = Get-CimInstance Win32_ComputerSystemProduct -ErrorAction Stop
        $bios = Get-CimInstance Win32_BIOS -ErrorAction Stop
        $bb = Get-CimInstance Win32_BaseBoard -ErrorAction Stop
        $enc = Get-CimInstance Win32_SystemEnclosure -ErrorAction Stop

        $shared.ComputerSystem = $cs
        $shared.Bios = $bios

        [ordered]@{
            hostname         = $env:COMPUTERNAME
            manufacturer     = ConvertTo-MTInventoryCleanString $cs.Manufacturer
            model            = ConvertTo-MTInventoryCleanString $cs.Model
            systemUuid       = ConvertTo-MTInventoryCleanString $csp.UUID
            biosSerialNumber = ConvertTo-MTInventoryCleanString $bios.SerialNumber
            assetTag         = ConvertTo-MTInventoryCleanString $enc.SMBIOSAssetTag
            chassis          = [ordered]@{
                serialNumber = ConvertTo-MTInventoryCleanString $enc.SerialNumber
                types        = @($enc.ChassisTypes | ForEach-Object { [int]$_ })
            }
            baseboard        = [ordered]@{
                manufacturer = ConvertTo-MTInventoryCleanString $bb.Manufacturer
                product      = ConvertTo-MTInventoryCleanString $bb.Product
                serialNumber = ConvertTo-MTInventoryCleanString $bb.SerialNumber
            }
        }
    }

    $os = New-MTInventorySection -Source "os" -FallbackData ([ordered]@{
        name = $null; edition = $null; displayVersion = $null; version = $null
        build = $null; ubr = $null; architecture = $null; installDate = $null
        lastBootAt = $null; locale = $null
    }) -Collector {
        $osCim = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        $cv = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -ErrorAction Stop

        [ordered]@{
            name           = ConvertTo-MTInventoryCleanString $osCim.Caption
            edition        = ConvertTo-MTInventoryCleanString $cv.EditionID
            displayVersion = ConvertTo-MTInventoryCleanString $cv.DisplayVersion
            version        = ConvertTo-MTInventoryCleanString $osCim.Version
            build          = if ($null -ne $osCim.BuildNumber) { [int]$osCim.BuildNumber } else { $null }
            ubr            = if ($null -ne $cv.UBR) { [int]$cv.UBR } else { $null }
            architecture   = ConvertTo-MTInventoryCleanString $osCim.OSArchitecture
            installDate    = ConvertTo-MTInventoryIso8601 $osCim.InstallDate
            lastBootAt     = ConvertTo-MTInventoryIso8601 $osCim.LastBootUpTime
            locale         = [Globalization.CultureInfo]::CurrentCulture.Name
        }
    }

    $firmwareWatch = [System.Diagnostics.Stopwatch]::StartNew()
    $firmwareErrors = New-Object System.Collections.Generic.List[object]
    $firmwareData = [ordered]@{
        type              = "unknown"
        manufacturer      = $null
        version           = $null
        releaseDate       = $null
        smbiosVersion     = $null
        secureBootEnabled = $null
    }
    try {
        $bios = if ($shared.ContainsKey("Bios")) { $shared.Bios } else { Get-CimInstance Win32_BIOS -ErrorAction Stop }
        $firmwareData.manufacturer = ConvertTo-MTInventoryCleanString $bios.Manufacturer
        $firmwareData.version = ConvertTo-MTInventoryCleanString $bios.SMBIOSBIOSVersion
        $firmwareData.releaseDate = ConvertTo-MTInventoryIso8601 $bios.ReleaseDate
        if ($null -ne $bios.SMBIOSMajorVersion -and $null -ne $bios.SMBIOSMinorVersion) {
            $firmwareData.smbiosVersion = "{0}.{1}" -f $bios.SMBIOSMajorVersion, $bios.SMBIOSMinorVersion
        }
    }
    catch {
        $firmwareErrors.Add((New-MTInventoryError -Code (Get-MTInventoryErrorCode $_) -Source "bios"))
    }

    try {
        $firmwareData.type = Get-MTFirmwareType
    }
    catch {
        $firmwareErrors.Add((New-MTInventoryError -Code (Get-MTInventoryErrorCode $_) -Source "firmware_type"))
    }

    if ($firmwareData.type -eq "uefi") {
        try {
            $firmwareData.secureBootEnabled = [bool](Confirm-SecureBootUEFI -ErrorAction Stop)
        }
        catch {
            $firmwareErrors.Add((New-MTInventoryError -Code (Get-MTInventoryErrorCode $_) -Source "secure_boot"))
        }
    }
    elseif ($firmwareData.type -eq "bios") {
        $firmwareData.secureBootEnabled = $false
    }

    $firmwareWatch.Stop()
    $firmware = New-MTInventoryPartialSection -Data $firmwareData -DurationMs $firmwareWatch.ElapsedMilliseconds -Errors $firmwareErrors.ToArray()

    $cpu = New-MTInventorySection -Source "cpu" -FallbackData ([ordered]@{ sockets = @() }) -Collector {
        $processors = @(Get-CimInstance Win32_Processor -ErrorAction Stop)
        [ordered]@{
            sockets = @($processors | ForEach-Object {
                [ordered]@{
                    socket            = ConvertTo-MTInventoryCleanString $_.SocketDesignation
                    manufacturer      = ConvertTo-MTInventoryCleanString $_.Manufacturer
                    model             = ConvertTo-MTInventoryCleanString $_.Name
                    cores             = if ($null -ne $_.NumberOfCores) { [int]$_.NumberOfCores } else { $null }
                    logicalProcessors = if ($null -ne $_.NumberOfLogicalProcessors) { [int]$_.NumberOfLogicalProcessors } else { $null }
                    maxClockMHz       = if ($null -ne $_.MaxClockSpeed) { [int]$_.MaxClockSpeed } else { $null }
                }
            })
        }
    }

    $memory = New-MTInventorySection -Source "memory" -FallbackData ([ordered]@{
        installedBytes = $null; systemVisibleBytes = $null; modules = @()
    }) -Collector {
        $cs = if ($shared.ContainsKey("ComputerSystem")) { $shared.ComputerSystem } else { Get-CimInstance Win32_ComputerSystem -ErrorAction Stop }
        $dimms = @(Get-CimInstance Win32_PhysicalMemory -ErrorAction Stop)
        [uint64]$installed = 0
        foreach ($dimm in $dimms) {
            if ($null -ne $dimm.Capacity) {
                $installed += [uint64]$dimm.Capacity
            }
        }

        [ordered]@{
            installedBytes    = [uint64]$installed
            systemVisibleBytes = ConvertTo-MTInventoryUInt64OrNull $cs.TotalPhysicalMemory
            modules = @($dimms | ForEach-Object {
                [ordered]@{
                    bank               = ConvertTo-MTInventoryCleanString $_.BankLabel
                    slot               = ConvertTo-MTInventoryCleanString $_.DeviceLocator
                    manufacturer       = ConvertTo-MTInventoryCleanString $_.Manufacturer
                    partNumber         = ConvertTo-MTInventoryCleanString $_.PartNumber
                    serialNumber       = ConvertTo-MTInventoryCleanString $_.SerialNumber
                    capacityBytes      = ConvertTo-MTInventoryUInt64OrNull $_.Capacity
                    type               = ConvertTo-MTMemoryType $_.SMBIOSMemoryType
                    ratedSpeedMHz      = if ($null -ne $_.Speed) { [int]$_.Speed } else { $null }
                    configuredSpeedMHz = if ($null -ne $_.ConfiguredClockSpeed) { [int]$_.ConfiguredClockSpeed } else { $null }
                }
            })
        }
    }

    $storage = New-MTInventorySection -Source "storage" -FallbackData ([ordered]@{ disks = @() }) -Collector {
        $physical = @(Get-PhysicalDisk -ErrorAction Stop)
        $diskDrives = @(Get-CimInstance Win32_DiskDrive -ErrorAction SilentlyContinue)

        [ordered]@{
            disks = @($physical | ForEach-Object {
                $p = $_
                $serial = ConvertTo-MTInventoryCleanString $p.SerialNumber
                $match = $null

                if ($null -ne $serial) {
                    $match = $diskDrives |
                        Where-Object { (ConvertTo-MTInventoryCleanString $_.SerialNumber) -eq $serial } |
                        Select-Object -First 1
                }

                if ($null -eq $match) {
                    $friendly = ConvertTo-MTInventoryCleanString $p.FriendlyName
                    if ($null -ne $friendly) {
                        $match = $diskDrives |
                            Where-Object { (ConvertTo-MTInventoryCleanString $_.Model) -eq $friendly } |
                            Select-Object -First 1
                    }
                }

                [ordered]@{
                    manufacturer = if ($null -ne $match) { ConvertTo-MTInventoryCleanString $match.Manufacturer } else { $null }
                    model        = if ($null -ne $match) { ConvertTo-MTInventoryCleanString $match.Model } else { ConvertTo-MTInventoryCleanString $p.FriendlyName }
                    serialNumber = $serial
                    capacityBytes = ConvertTo-MTInventoryUInt64OrNull $p.Size
                    busType      = ConvertTo-MTBusType $p.BusType
                    mediaType    = ConvertTo-MTMediaType $p.MediaType
                }
            })
        }
    }

    $volumesWatch = [System.Diagnostics.Stopwatch]::StartNew()
    $volumeErrors = New-Object System.Collections.Generic.List[object]
    $bitlockerByMountPoint = @{}

    try {
        $bitlockerVolumes = @(Get-BitLockerVolume -ErrorAction Stop)
        foreach ($bl in $bitlockerVolumes) {
            $mount = ConvertTo-MTInventoryCleanString $bl.MountPoint
            if ($null -eq $mount) {
                continue
            }

            $encrypted = $null
            $status = ConvertTo-MTInventoryCleanString ([string]$bl.VolumeStatus)
            if ($status -match '(?i)fullyencrypted|encryptioninprogress|encryptionpaused') {
                $encrypted = $true
            }
            elseif ($status -match '(?i)fullydecrypted') {
                $encrypted = $false
            }

            $bitlockerByMountPoint[$mount.TrimEnd([char[]]'\')] = $encrypted
        }
    }
    catch {
        $volumeErrors.Add((New-MTInventoryError -Code (Get-MTInventoryErrorCode $_) -Source "bitlocker"))
    }

    $volumeData = @()
    try {
        $volumeData = @(Get-Volume -ErrorAction Stop |
            Where-Object { $_.DriveType -eq "Fixed" } |
            ForEach-Object {
                $drive = if ($_.DriveLetter) { [string]$_.DriveLetter } else { $null }
                $mountCandidates = @()

                if ($null -ne $drive) {
                    $mountCandidates += ($drive + ":")
                }

                $path = ConvertTo-MTInventoryCleanString $_.Path
                if ($null -ne $path) {
                    $mountCandidates += $path.TrimEnd([char[]]'\')
                }

                $encrypted = $null
                foreach ($candidate in $mountCandidates) {
                    if ($bitlockerByMountPoint.ContainsKey($candidate)) {
                        $encrypted = $bitlockerByMountPoint[$candidate]
                        break
                    }
                }

                [ordered]@{
                    driveLetter  = $drive
                    label        = ConvertTo-MTInventoryCleanString $_.FileSystemLabel
                    fileSystem   = ConvertTo-MTInventoryCleanString $_.FileSystem
                    capacityBytes = ConvertTo-MTInventoryUInt64OrNull $_.Size
                    encrypted    = $encrypted
                }
            })
    }
    catch {
        $volumeErrors.Add((New-MTInventoryError -Code (Get-MTInventoryErrorCode $_) -Source "volumes"))
    }

    $volumesWatch.Stop()
    $volumes = New-MTInventoryPartialSection -Data $volumeData -DurationMs $volumesWatch.ElapsedMilliseconds -Errors $volumeErrors.ToArray()

    $gpu = New-MTInventorySection -Source "gpu" -FallbackData ([ordered]@{ adapters = @() }) -Collector {
        [ordered]@{
            adapters = @(Get-CimInstance Win32_VideoController -ErrorAction Stop | ForEach-Object {
                [ordered]@{
                    name          = ConvertTo-MTInventoryCleanString $_.Name
                    manufacturer  = ConvertTo-MTInventoryCleanString $_.AdapterCompatibility
                    driverVersion = ConvertTo-MTInventoryCleanString $_.DriverVersion
                    driverDate    = ConvertTo-MTInventoryIso8601 $_.DriverDate
                    pnpDeviceId   = ConvertTo-MTInventoryCleanString $_.PNPDeviceID
                }
            })
        }
    }

    $network = New-MTInventorySection -Source "network" -FallbackData ([ordered]@{ adapters = @() }) -Collector {
        $ipConfigByIndex = @{}
        @(Get-NetIPConfiguration -All -ErrorAction SilentlyContinue) | ForEach-Object {
            $ipConfigByIndex[[int]$_.InterfaceIndex] = $_
        }

        $ipAddressesByIndex = @{}
        @(Get-NetIPAddress -ErrorAction SilentlyContinue) | ForEach-Object {
            $index = [int]$_.InterfaceIndex
            if (-not $ipAddressesByIndex.ContainsKey($index)) {
                $ipAddressesByIndex[$index] = New-Object System.Collections.Generic.List[object]
            }
            $ipAddressesByIndex[$index].Add($_)
        }

        [ordered]@{
            adapters = @(Get-NetAdapter -IncludeHidden -ErrorAction Stop | ForEach-Object {
                $adapter = $_
                $index = [int]$adapter.ifIndex
                $config = $ipConfigByIndex[$index]
                $isVirtual = [bool]$adapter.Virtual
                $isPhysical = [bool]$adapter.HardwareInterface -and -not $isVirtual

                $addresses = New-Object System.Collections.Generic.List[object]
                if ($ipAddressesByIndex.ContainsKey($index)) {
                    foreach ($entry in $ipAddressesByIndex[$index].ToArray()) {
                        $address = ConvertTo-MTInventoryCleanString $entry.IPAddress
                        if ($null -eq $address) {
                            continue
                        }

                        $family = switch ([string]$entry.AddressFamily) {
                            "IPv4" { "ipv4" }
                            "IPv6" { "ipv6" }
                            default { ConvertTo-MTNetworkFamily $address }
                        }

                        if ($null -ne $family) {
                            $addresses.Add([ordered]@{
                                family       = $family
                                address      = $address
                                prefixLength = [int]$entry.PrefixLength
                            })
                        }
                    }
                }

                $gateways = New-Object System.Collections.Generic.List[object]
                if ($null -ne $config) {
                    foreach ($gateway in @($config.IPv4DefaultGateway | Where-Object { $null -ne $_ })) {
                        $address = ConvertTo-MTInventoryCleanString $gateway.NextHop
                        if ($null -ne $address) {
                            $gateways.Add([ordered]@{ family = "ipv4"; address = $address })
                        }
                    }
                    foreach ($gateway in @($config.IPv6DefaultGateway | Where-Object { $null -ne $_ })) {
                        $address = ConvertTo-MTInventoryCleanString $gateway.NextHop
                        if ($null -ne $address) {
                            $gateways.Add([ordered]@{ family = "ipv6"; address = $address })
                        }
                    }
                }

                $dnsServers = New-Object System.Collections.Generic.List[object]
                if ($null -ne $config -and $null -ne $config.DNSServer) {
                    foreach ($dns in @($config.DNSServer.ServerAddresses | Where-Object { $null -ne $_ })) {
                        $address = ConvertTo-MTInventoryCleanString $dns
                        if ($null -ne $address) {
                            $dnsServers.Add([ordered]@{
                                family  = ConvertTo-MTNetworkFamily $address
                                address = $address
                            })
                        }
                    }
                }

                [ordered]@{
                    name           = ConvertTo-MTInventoryCleanString $adapter.Name
                    description    = ConvertTo-MTInventoryCleanString $adapter.InterfaceDescription
                    interfaceIndex = $index
                    macAddress     = ConvertTo-MTInventoryCleanString $adapter.MacAddress
                    type           = ConvertTo-MTNetworkType -PhysicalMediaType $adapter.PhysicalMediaType -Description $adapter.InterfaceDescription -IsVirtual $isVirtual
                    isPhysical     = $isPhysical
                    isVirtual      = $isVirtual
                    driverVersion  = $null
                    driverDate     = $null
                    addresses      = $addresses.ToArray()
                    gateways       = $gateways.ToArray()
                    dnsServers     = $dnsServers.ToArray()
                }
            })
        }
    }

    $joinWatch = [System.Diagnostics.Stopwatch]::StartNew()
    $joinErrors = New-Object System.Collections.Generic.List[object]
    $joinData = [ordered]@{
        computerDomain   = $null
        domainJoined     = $null
        entraJoined      = $null
        enterpriseJoined = $null
        workplaceJoined  = $null
    }

    try {
        $cs = if ($shared.ContainsKey("ComputerSystem")) { $shared.ComputerSystem } else { Get-CimInstance Win32_ComputerSystem -ErrorAction Stop }
        $joinData.computerDomain = if ([bool]$cs.PartOfDomain) {
            ConvertTo-MTInventoryCleanString $cs.Domain
        }
        else {
            ConvertTo-MTInventoryCleanString $cs.Workgroup
        }
        $joinData.domainJoined = [bool]$cs.PartOfDomain
    }
    catch {
        $joinErrors.Add((New-MTInventoryError -Code (Get-MTInventoryErrorCode $_) -Source "computer_domain"))
    }

    try {
        $raw = @(& dsregcmd /status 2>&1)
        $joinData.entraJoined = ConvertTo-MTDsregBoolean (Get-MTDsregValue -Lines $raw -Name "AzureAdJoined")
        $joinData.enterpriseJoined = ConvertTo-MTDsregBoolean (Get-MTDsregValue -Lines $raw -Name "EnterpriseJoined")
        $joinData.workplaceJoined = ConvertTo-MTDsregBoolean (Get-MTDsregValue -Lines $raw -Name "WorkplaceJoined")
    }
    catch {
        $joinErrors.Add((New-MTInventoryError -Code (Get-MTInventoryErrorCode $_) -Source "dsregcmd"))
    }

    $joinWatch.Stop()
    $join = New-MTInventoryPartialSection -Data $joinData -DurationMs $joinWatch.ElapsedMilliseconds -Errors $joinErrors.ToArray()

    $tpmWatch = [System.Diagnostics.Stopwatch]::StartNew()
    $tpmErrors = New-Object System.Collections.Generic.List[object]
    $tpmData = [ordered]@{
        present      = $null
        version      = $null
        manufacturer = $null
        enabled      = $null
        activated    = $null
        owned        = $null
    }

    try {
        $tpmObject = Get-CimInstance -Namespace "root\CIMV2\Security\MicrosoftTpm" -ClassName Win32_Tpm -ErrorAction Stop
        if ($null -eq $tpmObject) {
            $tpmData.present = $false
        }
        else {
            $tpmData.present = $true
            $spec = ConvertTo-MTInventoryCleanString $tpmObject.SpecVersion
            if ($null -ne $spec) {
                $tpmData.version = (($spec -split ",")[0]).Trim()
            }
            $tpmData.manufacturer = ConvertTo-MTInventoryCleanString $tpmObject.ManufacturerIdTxt
            $tpmData.enabled = ConvertTo-MTInventoryNullableBoolean $tpmObject.IsEnabled_InitialValue
            $tpmData.activated = ConvertTo-MTInventoryNullableBoolean $tpmObject.IsActivated_InitialValue
            $tpmData.owned = ConvertTo-MTInventoryNullableBoolean $tpmObject.IsOwned_InitialValue
        }
    }
    catch {
        $tpmErrors.Add((New-MTInventoryError -Code (Get-MTInventoryErrorCode $_) -Source "tpm"))
    }

    $tpmWatch.Stop()
    $tpm = New-MTInventoryPartialSection -Data $tpmData -DurationMs $tpmWatch.ElapsedMilliseconds -Errors $tpmErrors.ToArray()

    $softwareWatch = [System.Diagnostics.Stopwatch]::StartNew()
    $softwareErrors = New-Object System.Collections.Generic.List[object]
    $softwareData = [ordered]@{
        win32 = @()
        appx  = @()
    }

    try {
        $softwareData.win32 = @(Get-MTClassicSoftwareInventory)
    }
    catch {
        $softwareErrors.Add((New-MTInventoryError -Code (Get-MTInventoryErrorCode $_) -Source "software_registry"))
    }

    try {
        $softwareData.appx = @(Get-MTAppxInventory)
    }
    catch {
        $softwareErrors.Add((New-MTInventoryError -Code (Get-MTInventoryErrorCode $_) -Source "appx"))
    }

    $softwareWatch.Stop()
    $software = New-MTInventoryPartialSection -Data $softwareData -DurationMs $softwareWatch.ElapsedMilliseconds -Errors $softwareErrors.ToArray()

    $users = New-MTInventorySection -Source "last_known_user" -FallbackData ([ordered]@{ lastKnownUser = $null }) -Collector {
        $cs = if ($shared.ContainsKey("ComputerSystem")) { $shared.ComputerSystem } else { Get-CimInstance Win32_ComputerSystem -ErrorAction Stop }
        [ordered]@{
            lastKnownUser = ConvertTo-MTInventoryCleanString $cs.UserName
        }
    }

    $maintenance = [ordered]@{
        status     = "ok"
        durationMs = $null
        errors     = @()
        data       = [ordered]@{
            windowsUpdate = [ordered]@{
                attempted = $false
                status    = "not_run"
                errorCode = $null
            }
        }
    }

    if ($null -ne $MaintenanceData -and $MaintenanceData.ContainsKey("windowsUpdate")) {
        $wu = $MaintenanceData.windowsUpdate
        $maintenance.data.windowsUpdate = [ordered]@{
            attempted = [bool]$wu.attempted
            status    = [string]$wu.status
            errorCode = if ($null -ne $wu.errorCode) { [string]$wu.errorCode } else { $null }
        }
    }

    $overallWatch.Stop()

    $sectionValues = @(
        $device, $os, $firmware, $cpu, $memory, $storage, $volumes, $gpu,
        $network, $join, $tpm, $software, $users
    )

    $overallStatus = "ok"
    if (@($sectionValues | Where-Object { $_.status -in @("partial", "unavailable", "error") }).Count -gt 0) {
        $overallStatus = "partial"
    }

    return [ordered]@{
        schemaVersion = "1.0"
        snapshotId    = $snapshotId
        collectedAt   = $collectedAt
        collector     = [ordered]@{
            name    = "Maintenance Toolkit"
            version = $CollectorVersion
        }
        collection    = [ordered]@{
            status     = $overallStatus
            durationMs = [int64]$overallWatch.ElapsedMilliseconds
        }
        device         = $device
        os             = $os
        firmware       = $firmware
        cpu            = $cpu
        memory         = $memory
        storage        = $storage
        volumes        = $volumes
        gpu            = $gpu
        network        = $network
        join           = $join
        tpm            = $tpm
        software       = $software
        users          = $users
        maintenance    = $maintenance
    }
}
