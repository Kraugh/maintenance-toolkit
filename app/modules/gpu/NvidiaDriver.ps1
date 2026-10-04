# NVIDIA catalogue adapter: validate every field before using a candidate.
function ConvertTo-MTNvidiaVersion {
    param([Parameter(Mandatory)][string]$WindowsVersion)
    $Parts = $WindowsVersion.Split('.')
    if ($Parts.Count -ne 4 -or $Parts[2] -notmatch '^\d+$' -or $Parts[3] -notmatch '^\d{1,4}$') { throw (Get-MTRuntimeText 'NVIDIA_VERSION_INVALID') }
    $Number = ([int]$Parts[2] % 10) * 10000 + [int]$Parts[3]
    return [version]('{0}.{1:00}' -f [math]::Floor($Number / 100), ($Number % 100))
}
function Get-MTNvidiaCandidate {
    param([Parameter(Mandatory)][object]$Response,[string]$ProductName='Quadro P620',[string]$SeriesName='Quadro Series')
    $Candidates = @()
    foreach ($Entry in @($Response.IDS)) {
        $Info = $Entry.downloadInfo
        if ($null -eq $Info) { continue }
        if ([string]$Info.Success -ne '1' -or [string]$Info.IsWHQL -ne '1' -or [string]$Info.IsBeta -ne '0' -or [string]$Info.IsActive -ne '1' -or [string]$Info.Is64Bit -ne '1' -or [string]$Info.IsFeaturePreview -ne '0') { continue }
        if ([string]$Info.Version -notmatch '^\d{3}\.\d{2}$') { continue }
        $OperatingSystems = @($Info.OSList | ForEach-Object { [uri]::UnescapeDataString([string]$_.OSName) })
        if ('Windows 11' -notin $OperatingSystems) { continue }
        $DesktopProducts = @($Info.series | Where-Object { [uri]::UnescapeDataString([string]$_.seriesname) -eq $SeriesName } | ForEach-Object { $_.products } | ForEach-Object { [uri]::UnescapeDataString([string]$_.productName) })
        if (-not @($DesktopProducts | Where-Object { (ConvertTo-MTNvidiaModelKey $_) -eq (ConvertTo-MTNvidiaModelKey $ProductName) }).Count) { continue }
        $Notes = [uri]::UnescapeDataString([string]$Info.ReleaseNotes)
        if ($Notes -notmatch 'Enterprise Production Branch') { continue }
        $Download = $null
        if (-not [uri]::TryCreate([string]$Info.DownloadURL,[UriKind]::Absolute,[ref]$Download)) { continue }
        if ($Download.Scheme -ne 'https' -or $Download.Host -notin @('us.download.nvidia.com','uk.download.nvidia.com','international.download.nvidia.com') -or $Download.UserInfo -or $Download.Query -or $Download.Fragment -or $Download.Port -ne 443) { continue }
        $VersionPattern = [regex]::Escape([string]$Info.Version)
        if ($Download.AbsolutePath -notmatch ('^/Windows/Quadro_Certified/' + $VersionPattern + '/' + $VersionPattern + '-quadro-rtx-desktop-notebook-win10-win11-64bit-international-dch-whql\.exe$')) { continue }
        if ([string]$Info.ID -notmatch '^\d+$') { continue }
        $Candidates += [pscustomobject]@{version=[string]$Info.Version;downloadUrl=$Download.AbsoluteUri;detailsUrl=('https://www.nvidia.com/en-us/drivers/details/' + [string]$Info.ID + '/');releaseId=[string]$Info.ID;releaseDate=[string]$Info.ReleaseDateTime;branch='Enterprise Production';productName=$ProductName;operatingSystem='Windows 11';whql=$true}
    }
    return ($Candidates | Sort-Object { [version]$_.version } -Descending | Select-Object -First 1)
}

function ConvertTo-MTNvidiaModelKey {
    param([Parameter(Mandatory)][string]$Name)
    # Only formatting/vendor prefixes are removed, never model qualifiers.
    return (($Name -replace '(?i)^\s*NVIDIA\s+','') -replace '[^A-Za-z0-9]','').ToUpperInvariant()
}
function Get-MTNvidiaProductMatch {
    param([Parameter(Mandatory)][string]$DeviceName,[Parameter(Mandatory)][object[]]$Products,[Parameter(Mandatory)][bool]$IsMobile)
    $Key=ConvertTo-MTNvidiaModelKey $DeviceName
    $Matches=@($Products | Where-Object {
        (ConvertTo-MTNvidiaModelKey $_.Name) -eq $Key -and
        ([bool]($_.SeriesName -match '(?i)notebook|laptop|mobile')) -eq $IsMobile
    } | Group-Object Value | ForEach-Object { $_.Group[0] })
    if ($Matches.Count -eq 1) { return $Matches[0] }
    return $null
}
