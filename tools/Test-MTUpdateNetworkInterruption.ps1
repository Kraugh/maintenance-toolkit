[CmdletBinding()]
param([string]$ProjectRoot='')
$ErrorActionPreference='Stop'
if(-not $ProjectRoot){$ProjectRoot=Split-Path -Parent $PSScriptRoot}
. (Join-Path $ProjectRoot 'app\core\UpdateTrust.ps1')
$Stamp=[TimeZoneInfo]::ConvertTimeBySystemTimeZoneId([datetime]::UtcNow,'W. Europe Standard Time').ToString('yyyyMMdd-HHmmss')
$Fixture=Join-Path $ProjectRoot ('launcher\build\MaintenanceToolkit-NetworkInterruption-'+$Stamp+'-'+[guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Path $Fixture | Out-Null
Write-Output ('Temporary fixture: '+$Fixture)
$OriginalFactory=(Get-Command New-MTUpdateWebRequest).ScriptBlock
try {
    Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Net;
public sealed class MTInterruptedNetworkStream : Stream {
    private readonly Stream inner;
    private readonly HttpWebRequest request;
    public static int BytesReadBeforeAbort;
    public MTInterruptedNetworkStream(Stream stream, HttpWebRequest webRequest) { inner=stream; request=webRequest; }
    public override int Read(byte[] buffer,int offset,int count) {
        int read=inner.Read(buffer,offset,Math.Min(count,32));
        if(read>0) { BytesReadBeforeAbort+=read; request.Abort(); }
        return read;
    }
    public override bool CanRead { get { return true; } }
    public override bool CanSeek { get { return false; } }
    public override bool CanWrite { get { return false; } }
    public override long Length { get { throw new NotSupportedException(); } }
    public override long Position { get { throw new NotSupportedException(); } set { throw new NotSupportedException(); } }
    public override void Flush() { }
    public override long Seek(long offset,SeekOrigin origin) { throw new NotSupportedException(); }
    public override void SetLength(long value) { throw new NotSupportedException(); }
    public override void Write(byte[] buffer,int offset,int count) { throw new NotSupportedException(); }
    protected override void Dispose(bool disposing) { if(disposing) inner.Dispose(); base.Dispose(disposing); }
}
'@
    # Only the transport factory is adapted. Production URL/redirect checks,
    # streaming, length checks and partial-file cleanup remain unchanged.
    # Every response uses real HTTPS; the client aborts the real request after
    # receiving 32 bytes from the published MT 4.0.6 ZIP. No script is executed.
    function New-MTUpdateWebRequest {
        param([string]$Url)
        $Request=[pscustomobject]@{Url=$Url;AllowAutoRedirect=$false;Timeout=30000;ReadWriteTimeout=30000}
        $Request | Add-Member ScriptMethod GetResponse {
            $Raw=[Net.HttpWebRequest]::Create($this.Url)
            $Raw.AllowAutoRedirect=$this.AllowAutoRedirect
            $Raw.Timeout=$this.Timeout;$Raw.ReadWriteTimeout=$this.ReadWriteTimeout
            $Response=$Raw.GetResponse()
            $Wrapper=[pscustomobject]@{Raw=$Response;Request=$Raw;StatusCode=$Response.StatusCode;ContentLength=$Response.ContentLength;Headers=$Response.Headers}
            $Wrapper | Add-Member ScriptMethod GetResponseStream { New-Object MTInterruptedNetworkStream ($this.Raw.GetResponseStream(),$this.Request) }
            $Wrapper | Add-Member ScriptMethod Close { $this.Raw.Close() }
            $Wrapper
        }
        $Request
    }
    [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
    $Destination=Join-Path $Fixture 'interrupted.zip'
    $Rejected=$false
    try {
        Save-MTUpdateDownload 'https://github.com/Kraugh/maintenance-toolkit/releases/download/v4.0.6/MaintenanceToolkit-4_0_6.zip' $Destination 10485760
    } catch { $Rejected=$true }
    if(-not $Rejected -or [MTInterruptedNetworkStream]::BytesReadBeforeAbort -lt 1) { throw 'Real HTTPS transfer was not interrupted after receiving data' }
    if((Test-Path -LiteralPath $Destination) -or (Test-Path -LiteralPath ($Destination+'.partial'))) { throw 'Interrupted transfer retained a partial/final payload' }
    Write-Output ('PASS: real HTTPS aborted after '+[MTInterruptedNetworkStream]::BytesReadBeforeAbort+' bytes; download rejected and partial/final payload absent')
} finally {
    Set-Item Function:New-MTUpdateWebRequest -Value $OriginalFactory
    # Remove only the empty directory created by this test; retain unexpected
    # contents for inspection rather than deleting recursively.
    if(@(Get-ChildItem -LiteralPath $Fixture -Force).Count -eq 0) { Remove-Item -LiteralPath $Fixture }
    Write-Output ('Temporary fixture removed: '+(-not (Test-Path -LiteralPath $Fixture)))
}
