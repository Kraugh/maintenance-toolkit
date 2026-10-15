# No URLs or certificate identities are taken from unverified metadata.
$script:MTUpdateCertificateSha256='0D2C78715390763915ED9CD0ABD279DB51E8C73F55E2756D197F45CFB4876A1B'
$script:MTUpdateManifestUrl='https://www.kraugh.it/api/maintenance-toolkit/update-v1.json'

function Read-MTStrictJson {
    param([Parameter(Mandatory)][string]$Path)
    # Tokenize JSON strings while retaining object scopes; reject ambiguous keys,
    # including escaped and case-variant keys, before ConvertFrom-Json in PS 5.1.
    $Text=Get-Content -LiteralPath $Path -Raw -Encoding UTF8 -ErrorAction Stop
    if ($Text.Length -gt 1048576) { throw 'MT41_METADATA_INVALID' }
    $Stack=New-Object 'System.Collections.Generic.Stack[object]'
    $Tokens=[regex]::Matches($Text,'"(?:\\.|[^"\\])*"|[{}\[\]:,]|[^\s{}\[\]:,]+')
    for($i=0;$i -lt $Tokens.Count;$i++) {
        $Token=$Tokens[$i].Value
        if ($Token -eq '{') { $Stack.Push((New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase))) }
        elseif($Token -eq '[') { $Stack.Push('array') }
        elseif($Token -in @('}',']')) { if($Stack.Count -eq 0){throw 'MT41_METADATA_INVALID'}; $null=$Stack.Pop() }
        elseif($Token.StartsWith('"') -and $i+1 -lt $Tokens.Count -and $Tokens[$i+1].Value -eq ':' -and $Stack.Count -gt 0) {
            $Key=ConvertFrom-Json ('{"key":'+$Token+'}')
            if($Stack.Peek() -is [string] -or -not $Stack.Peek().Add([string]$Key.key)) { throw 'MT41_METADATA_INVALID' }
        }
    }
    if($Stack.Count -ne 0){throw 'MT41_METADATA_INVALID'}
    $Text | ConvertFrom-Json -ErrorAction Stop
}

function Assert-MTUpdateSignature {
    param([Parameter(Mandatory)][string]$Path)
    $Signature=Get-AuthenticodeSignature -LiteralPath $Path -ErrorAction Stop
    if($Signature.Status -ne 'Valid' -or -not $Signature.SignerCertificate -or -not $Signature.TimeStamperCertificate) { throw 'MT41_SIGNATURE_INVALID' }
    if(@($Signature.SignerCertificate.Extensions | Where-Object {$_.Oid.Value -eq '2.5.29.37' -and $_.EnhancedKeyUsages.Value -contains '1.3.6.1.5.5.7.3.3'}).Count -eq 0){throw 'MT41_SIGNATURE_INVALID'}
    $Hash=[Security.Cryptography.SHA256]::Create()
    try { $Fingerprint=[BitConverter]::ToString($Hash.ComputeHash($Signature.SignerCertificate.RawData)).Replace('-','') } finally {$Hash.Dispose()}
    if($Fingerprint -cne $script:MTUpdateCertificateSha256){throw 'MT41_PUBLISHER_INVALID'}
    $Chain=New-Object Security.Cryptography.X509Certificates.X509Chain
    try {
        $Chain.ChainPolicy.RevocationMode='Online'
        $Chain.ChainPolicy.RevocationFlag='ExcludeRoot'
        $Chain.ChainPolicy.UrlRetrievalTimeout=[timespan]::FromSeconds(10)
        $null=$Chain.ChainPolicy.ApplicationPolicy.Add((New-Object Security.Cryptography.Oid '1.3.6.1.5.5.7.3.3'))
        if(-not $Chain.Build($Signature.SignerCertificate)){throw 'MT41_SIGNATURE_INVALID'}
    } finally {$Chain.Dispose()}
}

function Assert-MTUpdateCatalog {
    param([Parameter(Mandatory)][string]$Directory,[Parameter(Mandatory)][string]$Catalog)
    Assert-MTUpdateSignature -Path $Catalog
    $Result=Test-FileCatalog -Path $Directory -CatalogFilePath $Catalog -Detailed -ErrorAction Stop
    if($Result.Status -ne 'Valid' -or $Result.HashAlgorithm -ne 'SHA256'){throw 'MT41_CATALOG_INVALID'}
}

function Assert-MTUpdateUrl {
    param([string]$Url)
    $Uri=$null
    if(-not [uri]::TryCreate($Url,[UriKind]::Absolute,[ref]$Uri) -or $Uri.Scheme -ne 'https' -or $Uri.UserInfo -or -not $Uri.IsDefaultPort -or $Uri.Fragment -or $Uri.Host -notin @('www.kraugh.it','github.com','release-assets.githubusercontent.com')) {throw 'MT41_URL_INVALID'}
}

function Assert-MTUpdateManifest {
    param([Parameter(Mandatory)]$Manifest,[Parameter(Mandatory)][string]$InstalledVersion,[long]$MinimumSequence=0)
    foreach($Name in @('schemaVersion','productId','version','channel','architecture','sequence','publishedAt','expiresAt','minimumUpdaterVersion','artifacts')) {
        if(-not $Manifest.PSObject.Properties[$Name]){throw 'MT41_METADATA_INVALID'}
    }
    if(@($Manifest.PSObject.Properties.Name | Where-Object {$_ -notin @('schemaVersion','productId','version','channel','architecture','sequence','publishedAt','expiresAt','minimumUpdaterVersion','artifacts')}).Count){throw 'MT41_METADATA_INVALID'}
    if($Manifest.schemaVersion -cne '1.0' -or $Manifest.productId -cne 'maintenance-toolkit' -or $Manifest.channel -cne 'stable' -or $Manifest.architecture -cne 'x64' -or $Manifest.version -notmatch '^\d+\.\d+\.\d+$'){throw 'MT41_METADATA_INVALID'}
    if($Manifest.sequence -isnot [int] -and $Manifest.sequence -isnot [long]){throw 'MT41_METADATA_INVALID'}
    if($Manifest.sequence -lt $MinimumSequence -or $Manifest.sequence -lt 1){throw 'MT41_METADATA_INVALID'}
    if([version]$Manifest.version -le [version]($InstalledVersion.Split('-')[0])){throw 'MT41_NO_NEW_VERSION'}
    if([version]$Manifest.minimumUpdaterVersion -gt [version]'4.1.0'){throw 'MT41_METADATA_INVALID'}
    $Now=[DateTimeOffset]::UtcNow
    $Published=[DateTimeOffset]::Parse($Manifest.publishedAt,[Globalization.CultureInfo]::InvariantCulture)
    $Expires=[DateTimeOffset]::Parse($Manifest.expiresAt,[Globalization.CultureInfo]::InvariantCulture)
    if($Published -gt $Now.AddMinutes(5) -or $Expires -le $Now -or $Expires -le $Published){throw 'MT41_METADATA_INVALID'}
    foreach($Type in @('msi','zip')) {
        $Artifact=$Manifest.artifacts.$Type
        if(-not $Artifact -or $Artifact.sha256 -notmatch '^[0-9A-Fa-f]{64}$' -or ($Artifact.size -isnot [int] -and $Artifact.size -isnot [long]) -or $Artifact.size -le 0 -or $Artifact.size -gt 1073741824){throw 'MT41_METADATA_INVALID'}
        $Expected='MaintenanceToolkit-'+$Manifest.version.Replace('.','_')+'.'+$Type
        if($Artifact.fileName -cne $Expected){throw 'MT41_METADATA_INVALID'}
        Assert-MTUpdateUrl $Artifact.url
        if(([uri]$Artifact.url).AbsolutePath -notlike ('*/'+$Expected)){throw 'MT41_URL_INVALID'}
    }
    if($Manifest.artifacts.msi.upgradeCode -cne 'C1F2A740-51FD-4C40-A0F8-BE1D4E1B72A6' -or $Manifest.artifacts.zip.rootDirectory -cne ('Maintenance-Toolkit-'+$Manifest.version)){throw 'MT41_METADATA_INVALID'}
    $Catalog=$Manifest.artifacts.zip.catalog
    if(-not $Catalog -or $Catalog.fileName -cne ('MaintenanceToolkit-'+$Manifest.version.Replace('.','_')+'-payload.cat') -or $Catalog.sha256 -notmatch '^[a-fA-F0-9]{64}$' -or ($Catalog.size -isnot [int] -and $Catalog.size -isnot [long]) -or $Catalog.size -le 0 -or $Catalog.size -gt 1048576){throw 'MT41_METADATA_INVALID'}
    Assert-MTUpdateUrl $Catalog.url
    if(([uri]$Catalog.url).AbsolutePath -notlike ('*/'+$Catalog.fileName)){throw 'MT41_URL_INVALID'}
    $Manifest
}

function New-MTUpdateWebRequest {
    param([string]$Url)
    [Net.HttpWebRequest]::Create($Url)
}

function Save-MTUpdateDownload {
    param([Parameter(Mandatory)][string]$Url,[Parameter(Mandatory)][string]$Path,[long]$MaximumBytes=1073741824)
    $Partial=$Path+'.partial'
    $Response=$null;$InputStream=$null;$OutputStream=$null
    try {
        for($Redirect=0;$Redirect -lt 6;$Redirect++) {
            Assert-MTUpdateUrl $Url
            $Request=New-MTUpdateWebRequest $Url
            $Request.AllowAutoRedirect=$false;$Request.Timeout=30000;$Request.ReadWriteTimeout=30000
            $Response=$Request.GetResponse()
            if([int]$Response.StatusCode -in @(301,302,303,307,308)) {
                $Url=([uri]::new([uri]$Url,[string]$Response.Headers['Location'])).AbsoluteUri
                $Response.Close();$Response=$null;continue
            }
            if([int]$Response.StatusCode -ne 200 -or $Response.ContentLength -gt $MaximumBytes){throw 'MT41_DOWNLOAD_FAILED'}
            $InputStream=$Response.GetResponseStream();$OutputStream=[IO.File]::Create($Partial)
            $Buffer=New-Object byte[] 65536;$Total=0L;$Clock=[Diagnostics.Stopwatch]::StartNew()
            while(($Read=$InputStream.Read($Buffer,0,$Buffer.Length)) -gt 0) {
                if($Clock.Elapsed.TotalMinutes -gt 10){throw 'MT41_DOWNLOAD_FAILED'}
                $Total+=$Read;if($Total -gt $MaximumBytes){throw 'MT41_DOWNLOAD_FAILED'}
                $OutputStream.Write($Buffer,0,$Read)
                if(Get-Command T -ErrorAction SilentlyContinue){Write-Progress -Activity (T 'MT41_DOWNLOAD_ACTIVITY') -Status (T 'MT41_DOWNLOAD_ELAPSED' @([int]$Clock.Elapsed.TotalSeconds))}
            }
            if($Response.ContentLength -ge 0 -and $Total -ne $Response.ContentLength){throw 'MT41_DOWNLOAD_FAILED'}
            $OutputStream.Dispose();$OutputStream=$null
            Move-Item -LiteralPath $Partial -Destination $Path -ErrorAction Stop
            return
        }
        throw 'MT41_DOWNLOAD_FAILED'
    } finally {
        if($OutputStream){$OutputStream.Dispose()};if($InputStream){$InputStream.Dispose()};if($Response){$Response.Close()}
        if(Test-Path -LiteralPath $Partial){Remove-Item -LiteralPath $Partial -Force}
        if(Get-Command T -ErrorAction SilentlyContinue){Write-Progress -Activity (T 'MT41_DOWNLOAD_ACTIVITY') -Completed}
    }
}

function Assert-MTArtifactHash {
    param([string]$Path,$Artifact)
    if((Get-Item -LiteralPath $Path).Length -ne $Artifact.size -or (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash -ine $Artifact.sha256){throw 'MT41_HASH_INVALID'}
}

function Expand-MTVerifiedZip {
    param([string]$Archive,[string]$Destination,[string]$RootDirectory)
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $Zip=[IO.Compression.ZipFile]::OpenRead($Archive)
    try {
            $Paths=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
        $Total=0L
        foreach($Entry in $Zip.Entries) {
            $Name=$Entry.FullName.Replace('\','/')
            $Parts=$Name.TrimEnd('/').Split('/')
            if($Parts[0] -cne $RootDirectory -or $Parts -contains '..' -or $Parts -contains '.' -or $Name -match '[:\x00-\x1f]' -or $Name.StartsWith('/') -or -not $Paths.Add($Name.TrimEnd('/'))){throw 'MT41_ZIP_INVALID'}
            foreach($Part in $Parts){if($Part -eq '' -or $Part.EndsWith('.') -or $Part.EndsWith(' ') -or $Part -match '^(?i:con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.|$)'){throw 'MT41_ZIP_INVALID'}}
            if((($Entry.ExternalAttributes -shr 16) -band 0xF000) -eq 0xA000){throw 'MT41_ZIP_INVALID'}
            $Total+=$Entry.Length;if($Total -gt 2147483648 -or $Zip.Entries.Count -gt 10000){throw 'MT41_ZIP_INVALID'}
        }
        [IO.Compression.ZipFile]::ExtractToDirectory($Archive,$Destination)
    } finally {$Zip.Dispose()}
}
