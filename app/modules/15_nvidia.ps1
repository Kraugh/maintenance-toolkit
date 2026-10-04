# NVDOK: advisory-only NVIDIA professional GPU catalogue check.
# This module never downloads an installer, extracts a package or changes a driver.
. "$PSScriptRoot\00_common.ps1"
. "$PSScriptRoot\gpu\NvidiaDriver.ps1"
$ModuleName=Get-MTRuntimeText 'MODULE_NVIDIA'
$State=[ordered]@{schemaVersion=2;mode='advisory_only';status='analyzing';detectedAt=(Get-Date).ToString('o');devices=@();catalogue=@();installationAttempted=$false;downloadAttempted=$false;rebootRequired=$false}
$Work=Join-Path $env:MT_SESSION_DIR 'NVIDIA'
New-Item -ItemType Directory -Path $Work -Force | Out-Null
$LookupCache=@{}
function Save-NvdokState {
    $State | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $Work 'nvidia-status.json') -Encoding UTF8
}
function Get-NvdokLookup {
    param([int]$TypeId,[string]$ParentId)
    $CacheKey="$TypeId-$ParentId"
    if ($LookupCache.ContainsKey($CacheKey)) { return $LookupCache[$CacheKey] }
    $Uri='https://www.nvidia.com/Download/API/lookupValueSearch.aspx?TypeID='+$TypeId
    if ($ParentId) { $Uri+='&ParentID='+[uri]::EscapeDataString($ParentId) }
    $Reply=Invoke-WebRequest -Uri $Uri -UseBasicParsing -TimeoutSec 30 -ErrorAction Stop
    $FileName='catalogue-'+$CacheKey+'.xml'
    [string]$Reply.Content | Set-Content -LiteralPath (Join-Path $Work $FileName) -Encoding UTF8
    $State.catalogue += [pscustomobject]@{uri=$Uri;file=$FileName;statusCode=[int]$Reply.StatusCode}
    [xml]$Document=[string]$Reply.Content
    $Values=@(foreach ($Node in $Document.SelectNodes('//*[Name and Value]')) {
        $Value=$Node.SelectSingleNode('Value').InnerText
        $Name=$Node.SelectSingleNode('Name').InnerText
        if ($Value -match '^\d+$') { [pscustomobject]@{Name=$Name;Value=$Value} }
    })
    if ($Values.Count -eq 0) { throw (Get-MTRuntimeText 'NVIDIA_SCHEMA') }
    $LookupCache[$CacheKey]=$Values
    return $Values
}
try {
    $Devices=@(Get-PnpDevice -Class Display -PresentOnly -ErrorAction Stop | Where-Object { $_.InstanceId -match '^PCI\\VEN_10DE&' })
    if ($Devices.Count -eq 0) {
        $State.status='not_applicable';Save-NvdokState
        Set-ModuleResult $ModuleName 'SKIP' (Get-MTRuntimeText 'NVIDIA_NONE');exit 10
    }
    $Drivers=@(Get-CimInstance Win32_PnPSignedDriver -Filter "DeviceClass='DISPLAY'" -ErrorAction Stop)
    foreach ($Device in $Devices) {
        $Driver=$Drivers | Where-Object DeviceID -eq $Device.InstanceId | Select-Object -First 1
        $DeviceName=[string]$Device.FriendlyName
        if ($Driver -and $Driver.DeviceName) { $DeviceName=[string]$Driver.DeviceName }
        $WindowsDriver=if ($Driver) { [string]$Driver.DriverVersion } else { $null }
        try { $DetectedVersion=(ConvertTo-MTNvidiaVersion $WindowsDriver).ToString() } catch { $DetectedVersion=$null }
        $State.devices += [pscustomobject]@{name=$DeviceName;hardwareId=$Device.InstanceId;deviceStatus=[string]$Device.Status;windowsDriverVersion=$WindowsDriver;installedVersion=$DetectedVersion;candidate=$null;status='verification_incomplete';reason=$null}
    }
    $OS=Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
    $State.os=[pscustomobject]@{caption=$OS.Caption;version=$OS.Version;architecture=$OS.OSArchitecture}
    Save-NvdokState
    if ($OS.Caption -notmatch 'Windows 11' -or -not [Environment]::Is64BitOperatingSystem) { throw (Get-MTRuntimeText 'NVIDIA_PLATFORM') }
    $Computer=Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
    $Enclosures=@(Get-CimInstance Win32_SystemEnclosure -ErrorAction Stop)
    $MobileTypes=@(8,9,10,14,30,31,32)
    $IsMobile=($Computer.PCSystemType -eq 2 -or @($Enclosures.ChassisTypes | Where-Object { $_ -in $MobileTypes }).Count -gt 0)
    $DesktopTypes=@(3,4,5,6,7,13,15,16,17,23,24,35,36)
    $IsDesktop=($Computer.PCSystemType -in @(1,3) -or @($Enclosures.ChassisTypes | Where-Object { $_ -in $DesktopTypes }).Count -gt 0)
    if (-not $IsMobile -and -not $IsDesktop) { throw (Get-MTRuntimeText 'NVIDIA_FORM_FACTOR_UNVERIFIED') }
    $State.formFactor=if ($IsMobile) {'mobile'} else {'desktop'}
    Write-Main (Get-MTRuntimeText 'NVIDIA_DISCOVERY_START')
    $Families=@(Get-NvdokLookup 1 '')
    $ProfessionalFamilies=@($Families | Where-Object { $_.Name -match '(?i)Quadro|RTX.*PRO' })
    if ($ProfessionalFamilies.Count -ne 1) { throw (Get-MTRuntimeText 'NVIDIA_SCHEMA') }
    $Family=$ProfessionalFamilies[0]
    $Series=@(Get-NvdokLookup 2 $Family.Value)
    $EligibleSeries=@($Series | Where-Object { ([bool]($_.Name -match '(?i)notebook|laptop|mobile')) -eq $IsMobile })
    # Cache catalogue products across all GPUs; require an exact model match.
    $CatalogueProducts=@()
    foreach ($SeriesItem in $EligibleSeries) {
        foreach ($Product in @(Get-NvdokLookup 3 $SeriesItem.Value)) {
            $CatalogueProducts += [pscustomobject]@{Name=$Product.Name;Value=$Product.Value;SeriesId=$SeriesItem.Value;SeriesName=$SeriesItem.Name}
        }
    }
    $Warnings=0;$Available=0;$Current=0;$Incomplete=0
    foreach ($Gpu in $State.devices) {
        try {
            if ([string]::IsNullOrWhiteSpace($Gpu.windowsDriverVersion)) { throw (Get-MTRuntimeText 'NVIDIA_VERSION_INVALID') }
            $Installed=ConvertTo-MTNvidiaVersion $Gpu.windowsDriverVersion
            $Gpu.installedVersion=$Installed.ToString()
            Write-Main (Get-MTRuntimeText 'NVIDIA_DEVICE_INSTALLED' @($Gpu.name,$Installed))
            $Match=Get-MTNvidiaProductMatch -DeviceName $Gpu.name -Products $CatalogueProducts -IsMobile $IsMobile
            if ($null -eq $Match) { throw (Get-MTRuntimeText 'NVIDIA_MODEL_UNVERIFIED' @($Gpu.name)) }
            $Uri='https://gfwsl.geforce.com/services_toolkit/services/com/nvidia/services/AjaxDriverService.php?func=DriverManualLookup&psid='+$Match.SeriesId+'&pfid='+$Match.Value+'&osID=135&languageCode=1033&beta=0&isWHQL=1&dltype=-1&dch=1&upCRD=0&qnf=0&sort1=0&numberOfResults=100'
            $Reply=Invoke-WebRequest -Uri $Uri -UseBasicParsing -TimeoutSec 60 -ErrorAction Stop
            $FileName='driver-search-'+$Match.Value+'.json'
            $Reply.Content | Set-Content -LiteralPath (Join-Path $Work $FileName) -Encoding UTF8
            $State.catalogue += [pscustomobject]@{uri=$Uri;file=$FileName;statusCode=[int]$Reply.StatusCode}
            $Candidate=Get-MTNvidiaCandidate -Response ($Reply.Content | ConvertFrom-Json) -ProductName $Match.Name -SeriesName $Match.SeriesName
            if ($null -eq $Candidate) { throw (Get-MTRuntimeText 'NVIDIA_NO_CANDIDATE') }
            $Gpu.candidate=$Candidate
            if ($Installed -lt [version]$Candidate.version) {
                $Gpu.status='update_available';$Available++;$Warnings++
                Write-WarnLog (Get-MTRuntimeText 'NVIDIA_ADVISORY' @($Gpu.name,$Installed,$Candidate.version,$Candidate.detailsUrl)) 'NVIDIA'
            } else {
                $Gpu.status='up_to_date_in_selected_catalogue';$Current++
                Write-Ok (Get-MTRuntimeText 'NVIDIA_DEVICE_CURRENT' @($Gpu.name,$Installed,$Candidate.version)) 'NVIDIA'
            }
        }
        catch {
            $Gpu.status='verification_incomplete';$Gpu.reason=$_.Exception.Message;$Incomplete++;$Warnings++
            Write-WarnLog (Get-MTRuntimeText 'NVIDIA_DEVICE_FAILED' @($Gpu.name,$Gpu.reason)) 'NVIDIA'
        }
        Save-NvdokState
    }
    $State.status=if ($Warnings -gt 0) {'action_required'} else {'up_to_date_in_selected_catalogue'}
    $State.counts=[pscustomobject]@{available=$Available;current=$Current;incomplete=$Incomplete}
    Save-NvdokState
    $Detail=Get-MTRuntimeText 'NVIDIA_SUMMARY' @($Available,$Current,$Incomplete)
    $Actions=@($State.devices | Where-Object status -eq 'update_available' | ForEach-Object {
        Get-MTRuntimeText 'NVIDIA_ADVISORY' @($_.name,$_.installedVersion,$_.candidate.version,$_.candidate.detailsUrl)
    })
    if ($Actions.Count -gt 0) { $Detail+=' '+($Actions -join ' | ') }
    if ($Warnings -gt 0) { Set-ModuleResult $ModuleName 'WARN' $Detail;exit 20 }
    Set-ModuleResult $ModuleName 'OK' $Detail;exit 0
}
catch {
    $State.status='verification_incomplete';$State.error=$_.Exception.Message;Save-NvdokState
    Write-WarnLog $_.Exception.Message 'NVIDIA'
    Set-ModuleResult $ModuleName 'WARN' (Get-MTRuntimeText 'NVIDIA_DISCOVERY_FAILED' @($_.Exception.Message));exit 20
}
