# MT 5.0 Inventory source probe - read-only development utility
# Run from an elevated Windows PowerShell session.

$ErrorActionPreference = 'Continue'
$started = Get-Date

function Invoke-Probe {
    param([string]$Name,[scriptblock]$Script)
    $sw=[Diagnostics.Stopwatch]::StartNew()
    try {
        $data=& $Script
        $status='ok'; $err=$null
    } catch {
        $data=$null; $status='error'; $err=$_.Exception.Message
    }
    $sw.Stop()
    [ordered]@{ status=$status; durationMs=$sw.ElapsedMilliseconds; error=$err; data=$data }
}

function Iso($d) { if ($null -eq $d) { $null } else { $d.ToString('o') } }
function Clean($s) { if ($null -eq $s -or [string]::IsNullOrWhiteSpace([string]$s)) { $null } else { ([string]$s).Trim() } }

$identity=[Security.Principal.WindowsIdentity]::GetCurrent()
$principal=New-Object Security.Principal.WindowsPrincipal($identity)
$isElevated=$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

$sections=[ordered]@{}

$sections.deviceIdentity=Invoke-Probe 'deviceIdentity' {
    $cs=Get-CimInstance Win32_ComputerSystem
    $csp=Get-CimInstance Win32_ComputerSystemProduct
    $bios=Get-CimInstance Win32_BIOS
    $bb=Get-CimInstance Win32_BaseBoard
    $enc=Get-CimInstance Win32_SystemEnclosure
    [ordered]@{hostname=$env:COMPUTERNAME;manufacturer=Clean $cs.Manufacturer;model=Clean $cs.Model;systemUuid=Clean $csp.UUID;biosSerialNumber=Clean $bios.SerialNumber;biosVersion=Clean $bios.SMBIOSBIOSVersion;assetTag=Clean $enc.SMBIOSAssetTag;chassisSerialNumber=Clean $enc.SerialNumber;chassisTypes=@($enc.ChassisTypes);baseboardManufacturer=Clean $bb.Manufacturer;baseboardProduct=Clean $bb.Product;baseboardSerialNumber=Clean $bb.SerialNumber}
}

$sections.osFirmware=Invoke-Probe 'osFirmware' {
    $os=Get-CimInstance Win32_OperatingSystem; $bios=Get-CimInstance Win32_BIOS
    $cv=Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    # Firmware type: Windows exposes it reliably through GetFirmwareType.
    # 1 = BIOS, 2 = UEFI. Keep the numeric value in this probe for source validation.
    $fw=$null
    try {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class MTFirmwareProbe {
    [DllImport("kernel32.dll")]
    public static extern bool GetFirmwareType(out uint FirmwareType);
}
'@ -ErrorAction SilentlyContinue
        [uint32]$fwValue=0
        if ([MTFirmwareProbe]::GetFirmwareType([ref]$fwValue)) {
            $fw=$fwValue
        }
    } catch {}
    $sb=$null; $sbErr=$null; try {$sb=Confirm-SecureBootUEFI -ErrorAction Stop} catch {$sbErr=$_.Exception.Message}
    [ordered]@{caption=$os.Caption;version=$os.Version;buildNumber=$os.BuildNumber;architecture=$os.OSArchitecture;installDateIso=Iso $os.InstallDate;lastBootUpTimeIso=Iso $os.LastBootUpTime;currentCulture=[Globalization.CultureInfo]::CurrentCulture.Name;currentUICulture=[Globalization.CultureInfo]::CurrentUICulture.Name;osLanguageCode=$os.OSLanguage;editionId=$cv.EditionID;displayVersion=$cv.DisplayVersion;currentBuild=$cv.CurrentBuild;ubr=$cv.UBR;biosManufacturer=Clean $bios.Manufacturer;biosVersion=Clean $bios.SMBIOSBIOSVersion;biosReleaseDateIso=Iso $bios.ReleaseDate;smbiosMajor=$bios.SMBIOSMajorVersion;smbiosMinor=$bios.SMBIOSMinorVersion;firmwareType=$fw;secureBootEnabled=$sb;secureBootError=$sbErr}
}

$sections.cpuMemory=Invoke-Probe 'cpuMemory' {
    $cs=Get-CimInstance Win32_ComputerSystem
    [ordered]@{systemVisibleMemoryBytes=[uint64]$cs.TotalPhysicalMemory;cpus=@(Get-CimInstance Win32_Processor|ForEach-Object{[ordered]@{name=Clean $_.Name;manufacturer=Clean $_.Manufacturer;architecture=$_.Architecture;socket=Clean $_.SocketDesignation;cores=$_.NumberOfCores;logicalProcessors=$_.NumberOfLogicalProcessors;maxClockMHz=$_.MaxClockSpeed;processorId=Clean $_.ProcessorId}});dimms=@(Get-CimInstance Win32_PhysicalMemory|ForEach-Object{[ordered]@{deviceLocator=Clean $_.DeviceLocator;bankLabel=Clean $_.BankLabel;capacityBytes=[uint64]$_.Capacity;manufacturer=Clean $_.Manufacturer;partNumber=Clean $_.PartNumber;serialNumber=Clean $_.SerialNumber;speedMHz=$_.Speed;configuredClockMHz=$_.ConfiguredClockSpeed;formFactor=$_.FormFactor;memoryType=$_.MemoryType;smbiosMemoryType=$_.SMBIOSMemoryType}})}
}

$sections.storage=Invoke-Probe 'storage' {
    [ordered]@{physicalDisks=@(Get-PhysicalDisk|ForEach-Object{[ordered]@{friendlyName=$_.FriendlyName;serialNumber=Clean $_.SerialNumber;firmwareVersion=Clean $_.FirmwareVersion;sizeBytes=[uint64]$_.Size;mediaType=[string]$_.MediaType;busType=[string]$_.BusType;healthStatus=[string]$_.HealthStatus;operationalStatus=@($_.OperationalStatus|ForEach-Object{[string]$_})}});diskDrives=@(Get-CimInstance Win32_DiskDrive|ForEach-Object{[ordered]@{index=$_.Index;model=Clean $_.Model;serialNumber=Clean $_.SerialNumber;firmwareRevision=Clean $_.FirmwareRevision;pnpDeviceId=$_.PNPDeviceID;sizeBytes=if($_.Size){[uint64]$_.Size}else{$null};interfaceType=$_.InterfaceType;mediaType=$_.MediaType}})}
}

$sections.volumes=Invoke-Probe 'volumes' {
    @(
        Get-Volume -ErrorAction Stop |
        Where-Object DriveType -eq 'Fixed' |
        ForEach-Object {
            [ordered]@{
                driveLetter      = if ($_.DriveLetter) { [string]$_.DriveLetter } else { $null }
                label            = Clean $_.FileSystemLabel
                fileSystem       = $_.FileSystem
                sizeBytes        = [uint64]$_.Size
                freeBytes        = [uint64]$_.SizeRemaining
                usedBytes        = [uint64]($_.Size - $_.SizeRemaining)
                freePercent      = if ($_.Size) { [math]::Round(100 * $_.SizeRemaining / $_.Size, 2) } else { $null }
                healthStatus     = [string]$_.HealthStatus
                operationalStatus = @($_.OperationalStatus | ForEach-Object { [string]$_ })
                path             = $_.Path
            }
        }
    )
}

$sections.gpu=Invoke-Probe 'gpu' {
    @(Get-CimInstance Win32_VideoController|ForEach-Object{[ordered]@{name=Clean $_.Name;manufacturer=Clean $_.AdapterCompatibility;driverVersion=$_.DriverVersion;driverDateIso=Iso $_.DriverDate;adapterRamBytes=if($_.AdapterRAM){[uint64]$_.AdapterRAM}else{$null};pnpDeviceId=$_.PNPDeviceID;status=$_.Status}})
}

$sections.network=Invoke-Probe 'network' {
    @(
        Get-NetAdapter -IncludeHidden -ErrorAction Stop |
        ForEach-Object {
            $a = $_
            $ifIndex = $a.ifIndex

            $ipv4 = @(
                Get-NetIPAddress -InterfaceIndex $ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
                Where-Object { $_.IPAddress } |
                ForEach-Object { "$($_.IPAddress)/$($_.PrefixLength)" }
            )
            $ipv6 = @(
                Get-NetIPAddress -InterfaceIndex $ifIndex -AddressFamily IPv6 -ErrorAction SilentlyContinue |
                Where-Object { $_.IPAddress } |
                ForEach-Object { "$($_.IPAddress)/$($_.PrefixLength)" }
            )
            $gateway = @(
                Get-NetRoute -InterfaceIndex $ifIndex -AddressFamily IPv4 -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
                Where-Object { $_.NextHop -and $_.NextHop -ne '0.0.0.0' } |
                Sort-Object RouteMetric |
                ForEach-Object { $_.NextHop } |
                Select-Object -Unique
            )
            $dns = @(
                Get-DnsClientServerAddress -InterfaceIndex $ifIndex -ErrorAction SilentlyContinue |
                ForEach-Object { $_.ServerAddresses } |
                Where-Object { $_ } |
                Select-Object -Unique
            )
            $i = Get-NetIPInterface -InterfaceIndex $ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
                Select-Object -First 1
            $p = Get-NetConnectionProfile -InterfaceIndex $ifIndex -ErrorAction SilentlyContinue |
                Select-Object -First 1

            [ordered]@{
                interfaceIndex    = $ifIndex
                name              = $a.Name
                description       = $a.InterfaceDescription
                status            = [string]$a.Status
                macAddress        = Clean $a.MacAddress
                linkSpeed         = $a.LinkSpeed
                hardwareInterface = $a.HardwareInterface
                virtual           = $a.Virtual
                physicalMediaType = [string]$a.PhysicalMediaType
                ipv4              = $ipv4
                ipv6              = $ipv6
                gateway           = $gateway
                dns               = $dns
                dhcp              = if ($i) { [string]$i.Dhcp } else { $null }
                connectionState   = if ($p) { [string]$p.IPv4Connectivity } else { $null }
                profileName       = if ($p) { Clean $p.Name } else { $null }
                networkCategory   = if ($p) { [string]$p.NetworkCategory } else { $null }
            }
        }
    )
}

$sections.joinState=Invoke-Probe 'joinState' {
    $cs=Get-CimInstance Win32_ComputerSystem
    $raw=@(& dsregcmd /status 2>&1)
    function DsVal($name){$line=$raw|Where-Object{$_ -match ('^\s*'+[regex]::Escape($name)+'\s*:')}|Select-Object -First 1;if($line){($line -split ':',2)[1].Trim()}else{$null}}
    [ordered]@{domain=$cs.Domain;partOfDomain=$cs.PartOfDomain;workgroup=if(-not $cs.PartOfDomain){$cs.Workgroup}else{$null};azureAdJoined=DsVal 'AzureAdJoined';enterpriseJoined=DsVal 'EnterpriseJoined';domainJoined=DsVal 'DomainJoined';workplaceJoined=DsVal 'WorkplaceJoined'}
}

$sections.tpm=Invoke-Probe 'tpm' {
    $t=Get-CimInstance -Namespace 'root\CIMV2\Security\MicrosoftTpm' -ClassName Win32_Tpm -ErrorAction Stop
    if($null -eq $t){$null}else{[ordered]@{manufacturerId=$t.ManufacturerId;manufacturerIdTxt=Clean $t.ManufacturerIdTxt;manufacturerVersion=Clean $t.ManufacturerVersion;manufacturerVersionFull20=Clean $t.ManufacturerVersionFull20;physicalPresenceVersionInfo=Clean $t.PhysicalPresenceVersionInfo;specVersion=Clean $t.SpecVersion;isEnabled=$t.IsEnabled_InitialValue;isActivated=$t.IsActivated_InitialValue;isOwned=$t.IsOwned_InitialValue}}
}

$sections.softwareRegistry=Invoke-Probe 'softwareRegistry' {
    $sources=@([pscustomobject]@{Path='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*';Scope='machine';View='64'},[pscustomobject]@{Path='HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*';Scope='machine';View='32'},[pscustomobject]@{Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*';Scope='user';View='native'})
    $out=@(); foreach($s in $sources){$out+=@(Get-ItemProperty $s.Path -ErrorAction SilentlyContinue|Where-Object DisplayName|ForEach-Object{[ordered]@{name=Clean $_.DisplayName;version=Clean $_.DisplayVersion;publisher=Clean $_.Publisher;installDate=Clean $_.InstallDate;installLocation=Clean $_.InstallLocation;systemComponent=$_.SystemComponent;windowsInstaller=$_.WindowsInstaller;scope=$s.Scope;registryView=$s.View;registryKey=$_.PSChildName}})}; $out
}

$sections.appxCurrentUser=Invoke-Probe 'appxCurrentUser' {
    @(Get-AppxPackage -ErrorAction Stop|ForEach-Object{[ordered]@{name=$_.Name;packageFullName=$_.PackageFullName;version=[string]$_.Version;publisher=$_.Publisher;architecture=[string]$_.Architecture;isFramework=$_.IsFramework;isResourcePackage=$_.IsResourcePackage;signatureKind=[string]$_.SignatureKind;status=[string]$_.Status}})
}
$sections.appxAllUsers=Invoke-Probe 'appxAllUsers' {
    @(Get-AppxPackage -AllUsers -ErrorAction Stop|ForEach-Object{[ordered]@{name=$_.Name;packageFullName=$_.PackageFullName;version=[string]$_.Version;publisher=$_.Publisher;architecture=[string]$_.Architecture;isFramework=$_.IsFramework;isResourcePackage=$_.IsResourcePackage;signatureKind=[string]$_.SignatureKind;status=[string]$_.Status;users=@($_.PackageUserInformation|ForEach-Object{[ordered]@{sid=[string]$_.UserSecurityId;installState=[string]$_.InstallState}})}})
}

$sections.usersProfiles=Invoke-Probe 'usersProfiles' {
    $cs=Get-CimInstance Win32_ComputerSystem
    [ordered]@{currentUser=$cs.UserName;users=@(Get-CimInstance Win32_UserAccount -Filter 'LocalAccount=True'|ForEach-Object{[ordered]@{name=$_.Name;sid=$_.SID;disabled=$_.Disabled;lockedOut=$_.Lockout;passwordExpires=$_.PasswordExpires}});profiles=@(Get-CimInstance Win32_UserProfile|ForEach-Object{[ordered]@{sid=$_.SID;localPath=$_.LocalPath;loaded=$_.Loaded;special=$_.Special;lastUseTimeIso=Iso $_.LastUseTime}})}
}

$sections.hotfixes=Invoke-Probe 'hotfixes' {
    @(Get-HotFix -ErrorAction Stop|Sort-Object InstalledOn -Descending|ForEach-Object{[ordered]@{hotFixId=$_.HotFixID;description=$_.Description;installedOn=if($_.InstalledOn){$_.InstalledOn.ToString('yyyy-MM-dd')}else{$null}}})
}

$sections.drivers=Invoke-Probe 'drivers' {
    @(Get-CimInstance Win32_PnPSignedDriver -ErrorAction Stop|Where-Object DeviceName|ForEach-Object{[ordered]@{deviceName=$_.DeviceName;deviceClass=$_.DeviceClass;manufacturer=$_.Manufacturer;driverProvider=$_.DriverProviderName;driverVersion=$_.DriverVersion;driverDateIso=Iso $_.DriverDate;infName=$_.InfName;deviceId=$_.DeviceID;isSigned=$_.IsSigned}})
}

$sections.bitlocker=Invoke-Probe 'bitlocker' {
    @(Get-BitLockerVolume -ErrorAction Stop|ForEach-Object{[ordered]@{mountPoint=$_.MountPoint;volumeType=[string]$_.VolumeType;volumeStatus=[string]$_.VolumeStatus;protectionStatus=[string]$_.ProtectionStatus;encryptionMethod=[string]$_.EncryptionMethod;encryptionPercentage=$_.EncryptionPercentage;autoUnlockEnabled=$_.AutoUnlockEnabled}})
}

$sections.winget=Invoke-Probe 'winget' {
    $cmd=Get-Command winget -ErrorAction Stop
    $raw=@(& $cmd.Source list --disable-interactivity --accept-source-agreements 2>&1)
    [ordered]@{exitCode=$LASTEXITCODE;lineCount=$raw.Count;raw=$raw}
}

$sections.servicesExperimental=Invoke-Probe 'servicesExperimental' {
    $s=@(Get-CimInstance Win32_Service -ErrorAction Stop)
    [ordered]@{count=$s.Count;running=@($s|Where-Object State -eq 'Running').Count;stopped=@($s|Where-Object State -eq 'Stopped').Count;auto=@($s|Where-Object StartMode -eq 'Auto').Count;manual=@($s|Where-Object StartMode -eq 'Manual').Count;disabled=@($s|Where-Object StartMode -eq 'Disabled').Count}
}

$ended=Get-Date
$result=[ordered]@{
    probe='MT 5.0 Inventory Source Probe'
    probeVersion='0.2'
    startedAt=$started.ToString('o')
    endedAt=$ended.ToString('o')
    durationMs=[math]::Round(($ended-$started).TotalMilliseconds)
    computerName=$env:COMPUTERNAME
    powershellVersion=$PSVersionTable.PSVersion.ToString()
    identity=$identity.Name
    isElevated=$isElevated
    sections=$sections
}

$stamp=Get-Date -Format 'yyyyMMdd-HHmmss'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$out=Join-Path $scriptDir "MT-Inventory-Probe_${env:COMPUTERNAME}_$stamp.json"
$result|ConvertTo-Json -Depth 12|Set-Content -LiteralPath $out -Encoding UTF8
Write-Host "`nProbe complete." -ForegroundColor Green
Write-Host "Output: $out"
Write-Host "Total duration: $($result.durationMs) ms"
Write-Host "Elevated: $isElevated"
Write-Host "`nSection timings:"
$sections.GetEnumerator()|ForEach-Object{Write-Host ('{0,-24} {1,8} ms  {2}' -f $_.Key,$_.Value.durationMs,$_.Value.status)}
Set-Clipboard -Value $out
Write-Host "`nOutput file path copied to clipboard."
