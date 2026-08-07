# MT4 native Network Diagnostics report service
# Engine baseline: NDP 0.0.19-RC
#
# Responsibilities:
# - report identity and filenames;
# - orchestration of topology/routing/rules for report generation;
# - TXT and correlated JSON artifacts.
#
# It does NOT elevate, start another process, or own a menu.

function Format-MTNetworkReportText {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Template,

        [AllowNull()]
        [object[]]$Arguments = @()
    )

    try {
        return [string]::Format(
            [System.Globalization.CultureInfo]::CurrentCulture,
            $Template,
            $Arguments
        )
    }
    catch {
        throw (
            "Report format failure. Template='{0}' Arguments={1}. {2}" -f @(
                $Template,
                @($Arguments).Count,
                $_.Exception.Message
            )
        )
    }
}

function ConvertTo-MTAsciiSafeToken {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$Value,
        [string]$Fallback = "unknown"
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $Fallback
    }

    $Safe = $Value -replace '[^A-Za-z0-9._-]', '-'
    $Safe = $Safe -replace '-{2,}', '-'
    $Safe = $Safe.Trim('-', '.', '_')

    if ([string]::IsNullOrWhiteSpace($Safe)) {
        return $Fallback
    }

    return $Safe
}

function Get-MTNetworkArtifactPrefix {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ComputerName,
        [Parameter(Mandatory)][string]$RunId,
        [string]$ReportType = "Technical",
        [string]$OptionCode = "N2"
    )

    $SafeComputer = ConvertTo-MTAsciiSafeToken -Value $ComputerName
    $SafeRunId = ConvertTo-MTAsciiSafeToken -Value $RunId
    $SafeReportType = ConvertTo-MTAsciiSafeToken -Value $ReportType
    $SafeOption = ConvertTo-MTAsciiSafeToken -Value $OptionCode

    return Format-MTNetworkReportText `
        -Template "MT4-NET-{0}-{1}-{2}-{3}" `
        -Arguments @(
            $SafeOption,
            $SafeReportType,
            $SafeComputer,
            $SafeRunId
        )
}

function New-MTNetworkReportHeader {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$LanguageData,
        [Parameter(Mandatory)][string]$Version,
        [Parameter(Mandatory)][string]$RunId,
        [Parameter(Mandatory)][string]$ComputerName,
        [Parameter(Mandatory)][datetime]$Timestamp,
        [string]$OptionCode = "N2",
        [string]$ReportType = "Technical",
        [bool]$SpeedTestIncluded = $false
    )

    $SpeedText = if ($SpeedTestIncluded) {
        Get-MTText -LanguageData $LanguageData -Key "YES"
    }
    else {
        Get-MTText -LanguageData $LanguageData -Key "NO"
    }

    return @(
        (Format-MTNetworkReportText `
            -Template "Maintenance Toolkit : {0}" `
            -Arguments @($Version))
        (Format-MTNetworkReportText `
            -Template "{0} : {1} - {2}" `
            -Arguments @(
                (Get-MTText -LanguageData $LanguageData -Key "REPORT_MENU_OPTION"),
                $OptionCode,
                (Get-MTText -LanguageData $LanguageData -Key "NETWORK_TECHNICAL_REPORT")
            ))
        (Format-MTNetworkReportText `
            -Template "{0} : {1}" `
            -Arguments @(
                (Get-MTText -LanguageData $LanguageData -Key "REPORT_TYPE"),
                $ReportType
            ))
        (Format-MTNetworkReportText `
            -Template "SpeedTest : {0}" `
            -Arguments @($SpeedText))
        (Format-MTNetworkReportText `
            -Template "{0} : {1}" `
            -Arguments @(
                (Get-MTText -LanguageData $LanguageData -Key "REPORT_SCOPE"),
                (Get-MTText -LanguageData $LanguageData -Key "NETWORK_REPORT_SCOPE")
            ))
        (Format-MTNetworkReportText `
            -Template "RunId : {0}" `
            -Arguments @($RunId))
        (Format-MTNetworkReportText `
            -Template "{0} : {1}" `
            -Arguments @(
                (Get-MTText -LanguageData $LanguageData -Key "SESSION_COMPUTER"),
                $ComputerName
            ))
        (Format-MTNetworkReportText `
            -Template "{0} : {1}" `
            -Arguments @(
                (Get-MTText -LanguageData $LanguageData -Key "REPORT_TIMESTAMP"),
                $Timestamp.ToString("yyyy-MM-dd HH:mm:ss")
            ))
    )
}

function Add-MTNetworkReportSection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$Lines,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Title
    )

    if ($null -eq $Lines -or $null -eq $Lines.PSObject.Methods['Add']) {
        throw 'Report line buffer is not a mutable collection.'
    }

    [void]$Lines.Add("")
    [void]$Lines.Add($Title.ToUpperInvariant())
    [void]$Lines.Add("-" * 78)
}

function Add-MTNetworkReportKeyValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$Lines,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Key,

        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $Lines -or $null -eq $Lines.PSObject.Methods['Add']) {
        throw 'Report line buffer is not a mutable collection.'
    }

    $Text = if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) {
        "-"
    }
    else {
        [string]$Value
    }

    [void]$Lines.Add(
        (Format-MTNetworkReportText `
            -Template "{0,-24}: {1}" `
            -Arguments @($Key, $Text))
    )
}

function Invoke-MTNetworkTechnicalReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ProjectRoot,
        [Parameter(Mandatory)][object]$LanguageData,
        [Parameter(Mandatory)][string]$Version,
        [string]$RunId = $null,
        [switch]$SpeedTest,
        [string]$OptionCode = 'N2',
        [string]$ReportType = 'Technical'
    )

    if ([string]::IsNullOrWhiteSpace($RunId)) {
        $RunId = Get-Date -Format "yyyyMMdd-HHmmss"
    }

    if (-not (Get-Command Get-NDTopology -ErrorAction SilentlyContinue)) {
        . (Join-Path $ProjectRoot 'app/modules/network/NetworkFoundation.ps1')
        $null = Import-MTNetworkDiagnosticsFoundation -ProjectRoot $ProjectRoot
    }

    $NetworkSettings = Get-Content `
        -LiteralPath (Join-Path $ProjectRoot 'config/network.json') `
        -Raw `
        -Encoding UTF8 |
        ConvertFrom-Json

    $RulesConfiguration = Get-Content `
        -LiteralPath (Join-Path $ProjectRoot 'rules/network.json') `
        -Raw `
        -Encoding UTF8 |
        ConvertFrom-Json

    $RuntimeSettings = Get-Content `
        -LiteralPath (Join-Path $ProjectRoot 'config/settings.json') `
        -Raw `
        -Encoding UTF8 |
        ConvertFrom-Json

    $ReportRelativePath = [string]$RuntimeSettings.Paths.Reports

    if ([string]::IsNullOrWhiteSpace($ReportRelativePath)) {
        $ReportRelativePath = "reports"
    }

    $ReportDirectory = Join-Path `
        $ProjectRoot `
        $ReportRelativePath

    if (-not (Test-Path -LiteralPath $ReportDirectory)) {
        New-Item `
            -ItemType Directory `
            -Path $ReportDirectory `
            -Force |
            Out-Null
    }

    $Timestamp = Get-Date
    $ComputerName = $env:COMPUTERNAME
    $ArtifactPrefix = Get-MTNetworkArtifactPrefix `
        -ComputerName $ComputerName `
        -RunId $RunId `
        -ReportType $ReportType `
        -OptionCode $OptionCode

    $TxtPath = Join-Path $ReportDirectory ($ArtifactPrefix + ".txt")
    $TopologyPath = Join-Path $ReportDirectory ($ArtifactPrefix + "-Topology.json")
    $RulesPath = Join-Path $ReportDirectory ($ArtifactPrefix + "-Rules.json")
    $SpeedTestPath = Join-Path $ReportDirectory ($ArtifactPrefix + "-SpeedTest.json")

    $Lines = New-Object System.Collections.Generic.List[string]

    foreach ($HeaderLine in (
        New-MTNetworkReportHeader `
            -LanguageData $LanguageData `
            -Version $Version `
            -RunId $RunId `
            -ComputerName $ComputerName `
            -Timestamp $Timestamp `
            -OptionCode $OptionCode `
            -ReportType $ReportType `
            -SpeedTestIncluded ([bool]$SpeedTest)
    )) {
        [void]$Lines.Add($HeaderLine)
    }

    [void]$Lines.Add("=" * 78)

    Add-MTNetworkReportSection `
        -Lines $Lines `
        -Title (Get-MTText $LanguageData "REPORT_ENVIRONMENT")

    try {
        $OS = Get-CimInstance `
            -ClassName Win32_OperatingSystem `
            -ErrorAction Stop

        Add-MTNetworkReportKeyValue `
            -Lines $Lines `
            -Key (Get-MTText $LanguageData "REPORT_OS") `
            -Value ([string]$OS.Caption)

        Add-MTNetworkReportKeyValue `
            -Lines $Lines `
            -Key (Get-MTText $LanguageData "REPORT_OS_VERSION") `
            -Value (Format-MTNetworkReportText `
                -Template "{0} build {1}" `
                -Arguments @($OS.Version, $OS.BuildNumber))
    }
    catch {
        Add-MTNetworkReportKeyValue `
            -Lines $Lines `
            -Key (Get-MTText $LanguageData "REPORT_OS") `
            -Value $_.Exception.Message
    }

    Add-MTNetworkReportKeyValue `
        -Lines $Lines `
        -Key "PowerShell" `
        -Value $PSVersionTable.PSVersion.ToString()

    Add-MTNetworkReportKeyValue `
        -Lines $Lines `
        -Key (Get-MTText $LanguageData "SESSION_USER") `
        -Value (Format-MTNetworkReportText `
            -Template "{0}\{1}" `
            -Arguments @($env:USERDOMAIN, $env:USERNAME))

    $Profile = Start-MTProfiler -Name "MTNetworkTechnicalReport"
    $Topology = $null
    $Routing = $null
    $RuleEvaluation = $null

    try {
        $Step = Start-MTProfilerStep -Name "Topology"
        $Topology = Get-NDTopology -Settings $NetworkSettings
        $null = Stop-MTProfilerStep -Step $Step -Status "OK"
    }
    catch {
        $null = Stop-MTProfilerStep `
            -Step $Step `
            -Status "ERROR" `
            -Details $_.Exception.Message

        Add-MTNetworkReportSection `
            -Lines $Lines `
            -Title (Get-MTText $LanguageData "NETWORK_TOPOLOGY_ENGINE")

        [void]$Lines.Add(
            (Format-MTNetworkReportText `
                -Template "{0}: {1}" `
                -Arguments @(
                    (Get-MTText $LanguageData "STATUS_ERROR"),
                    $_.Exception.Message
                ))
        )
    }

    try {
        $Step = Start-MTProfilerStep -Name "Routing"
        $Routing = Get-NDRoutingAnalysis -Settings $NetworkSettings
        $null = Stop-MTProfilerStep -Step $Step -Status "OK"
    }
    catch {
        $null = Stop-MTProfilerStep `
            -Step $Step `
            -Status "ERROR" `
            -Details $_.Exception.Message
    }

    if ($null -ne $Topology) {
        try {
            $Step = Start-MTProfilerStep -Name "Rules"
            $RuleEvaluation = Invoke-NDRules `
                -Topology $Topology `
                -RulesConfiguration $RulesConfiguration
            $null = Stop-MTProfilerStep -Step $Step -Status "OK"
        }
        catch {
            $null = Stop-MTProfilerStep `
                -Step $Step `
                -Status "ERROR" `
                -Details $_.Exception.Message
        }

        Add-MTNetworkReportSection `
            -Lines $Lines `
            -Title (Get-MTText $LanguageData "NETWORK_TOPOLOGY_SUMMARY")

        $LogicalAdapter = $Topology.EffectivePath.LogicalAdapter
        $BackendPresentation = Get-MTNetworkPhysicalBackendPresentation `
            -Topology $Topology `
            -LanguageData $LanguageData
        $DefaultRoute = $Topology.EffectivePath.DefaultRoute
        $HyperVSwitch = $Topology.EffectivePath.HyperVSwitch

        Add-MTNetworkReportKeyValue `
            -Lines $Lines `
            -Key (Get-MTText $LanguageData "NETWORK_LOGICAL_INTERFACE") `
            -Value $(if ($null -ne $LogicalAdapter) {
                Format-MTNetworkReportText `
                    -Template "{0} - {1}" `
                    -Arguments @($LogicalAdapter.Name, $LogicalAdapter.Description)
            } else { "-" })

        Add-MTNetworkReportKeyValue `
            -Lines $Lines `
            -Key $BackendPresentation.Label `
            -Value $BackendPresentation.Value

        if (
            $null -ne $HyperVSwitch -and
            -not [string]::IsNullOrWhiteSpace([string]$HyperVSwitch.SwitchName)
        ) {
            Add-MTNetworkReportKeyValue `
                -Lines $Lines `
                -Key "Hyper-V vSwitch" `
                -Value (Format-MTNetworkReportText `
                    -Template "{0} ({1})" `
                    -Arguments @($HyperVSwitch.SwitchName, $HyperVSwitch.SwitchType))
        }

        Add-MTNetworkReportKeyValue `
            -Lines $Lines `
            -Key (Get-MTText $LanguageData "NETWORK_DEFAULT_GATEWAY") `
            -Value $(if ($null -ne $DefaultRoute) { $DefaultRoute.NextHop } else { "-" })

        Add-MTNetworkReportKeyValue `
            -Lines $Lines `
            -Key (Get-MTText $LanguageData "NETWORK_ROUTING_MODE") `
            -Value (
                Get-MTNetworkRoutingModeText `
                    -LanguageData $LanguageData `
                    -RoutingMode ([string]$Topology.Summary.RoutingModeCandidate)
            )

        Add-MTNetworkReportKeyValue `
            -Lines $Lines `
            -Key (Get-MTText $LanguageData "NETWORK_ACTIVE_VPN_COUNT") `
            -Value $Topology.Summary.ActiveVPNCount

        Add-MTNetworkReportKeyValue `
            -Lines $Lines `
            -Key (Get-MTText $LanguageData "NETWORK_DEFAULT_ROUTE_COUNT") `
            -Value $Topology.Summary.DefaultRouteCount

        Add-MTNetworkReportKeyValue `
            -Lines $Lines `
            -Key (Get-MTText $LanguageData "NETWORK_TOTAL_ROUTE_COUNT") `
            -Value $Topology.Summary.RouteCount

        Add-MTNetworkReportSection `
            -Lines $Lines `
            -Title (Get-MTText $LanguageData "REPORT_INTERFACES")

        foreach ($Adapter in @(
            $Topology.Adapters |
            Sort-Object InterfaceIndex
        )) {
            $Flags = New-Object System.Collections.Generic.List[string]

            # Windows can expose a Hyper-V guest NIC with both
            # HardwareInterface=true and IsVirtual=true. In human output,
            # "virtual" takes precedence so we do not describe the same guest
            # adapter as both physical and virtual.
            if ([bool]$Adapter.IsVirtual) {
                [void]$Flags.Add(
                    (Get-MTText $LanguageData "REPORT_FLAG_VIRTUAL")
                )
            }
            elseif ([bool]$Adapter.HardwareInterface) {
                [void]$Flags.Add(
                    (Get-MTText $LanguageData "REPORT_FLAG_PHYSICAL")
                )
            }

            if ([bool]$Adapter.IsVPN) {
                [void]$Flags.Add("VPN")
            }

            $FlagText = if ($Flags.Count -gt 0) {
                $Flags -join ","
            }
            else {
                "-"
            }

            [void]$Lines.Add(
                (Format-MTNetworkReportText `
                    -Template "[{0}] {1} | {2} | {3} | {4} | {5}" `
                    -Arguments @(
                        $Adapter.InterfaceIndex,
                        $Adapter.Name,
                        $Adapter.Status,
                        $Adapter.LinkSpeed,
                        $FlagText,
                        $Adapter.Description
                    ))
            )

            $IPv4 = @(
                $Topology.IPv4Addresses |
                Where-Object {
                    $_.InterfaceIndex -eq $Adapter.InterfaceIndex
                } |
                ForEach-Object {
                    Format-MTNetworkReportText `
                        -Template "{0}/{1}" `
                        -Arguments @($_.IPAddress, $_.PrefixLength)
                }
            )

            if ($IPv4.Count -gt 0) {
                [void]$Lines.Add(
                    (Format-MTNetworkReportText `
                        -Template "    IPv4: {0}" `
                        -Arguments @(($IPv4 -join ", ")))
                )
            }

            $DNS = @(
                $Topology.DNS |
                Where-Object {
                    $_.InterfaceIndex -eq $Adapter.InterfaceIndex
                } |
                ForEach-Object { @($_.Servers) }
            )

            if ($DNS.Count -gt 0) {
                [void]$Lines.Add(
                    (Format-MTNetworkReportText `
                        -Template "    DNS : {0}" `
                        -Arguments @(($DNS -join ", ")))
                )
            }
        }

        Add-MTNetworkReportSection `
            -Lines $Lines `
            -Title (Get-MTText $LanguageData "REPORT_DEFAULT_ROUTES")

        foreach ($Route in @($Topology.DefaultRoutes)) {
            [void]$Lines.Add(
                (Format-MTNetworkReportText `
                    -Template "{0} -> {1} | if={2} ({3}) | metric={4}" `
                    -Arguments @(
                        $Route.DestinationPrefix,
                        $Route.NextHop,
                        $Route.InterfaceIndex,
                        $Route.InterfaceAlias,
                        $Route.TotalMetric
                    ))
            )
        }

        Add-MTNetworkReportSection `
            -Lines $Lines `
            -Title (Get-MTText $LanguageData "REPORT_VPN")

        Add-MTNetworkReportKeyValue `
            -Lines $Lines `
            -Key (Get-MTText $LanguageData "NETWORK_ACTIVE_VPN_COUNT") `
            -Value $Topology.Summary.ActiveVPNCount

        foreach ($VPN in @($Topology.ActiveVPNAdapters)) {
            [void]$Lines.Add(
                (Format-MTNetworkReportText `
                    -Template "[{0}] {1} | {2}" `
                    -Arguments @(
                        $VPN.InterfaceIndex,
                        $VPN.Name,
                        $VPN.Description
                    ))
            )
        }

        if ($null -ne $RuleEvaluation) {
            Add-MTNetworkReportSection `
                -Lines $Lines `
                -Title (Get-MTText $LanguageData "NETWORK_AUTOMATIC_ANALYSIS")

            $Triggered = @($RuleEvaluation.Triggered)

            if ($Triggered.Count -eq 0) {
                [void]$Lines.Add(
                    (Get-MTText $LanguageData "NETWORK_RULES_NONE")
                )
            }
            else {
                foreach ($Rule in $Triggered) {
                    $Title = Get-MTText `
                        -LanguageData $LanguageData `
                        -Key ([string]$Rule.TitleKey)

                    $Message = Get-MTText `
                        -LanguageData $LanguageData `
                        -Key ([string]$Rule.MessageKey)

                    [void]$Lines.Add(
                        (Format-MTNetworkReportText `
                            -Template "[{0}] {1} {2}: {3}" `
                            -Arguments @(
                                $Rule.Severity,
                                $Rule.Id,
                                $Title,
                                $Message
                            ))
                    )
                }
            }
        }
    }

    $SpeedTestResult = $null

    if ($SpeedTest) {
        Add-MTNetworkReportSection `
            -Lines $Lines `
            -Title (Get-MTText $LanguageData 'SPEEDTEST_SECTION')

        $SpeedStep = Start-MTProfilerStep -Name 'SpeedTest'

        $SpeedTestResult = Invoke-MTNetworkSpeedTest `
            -ProjectRoot $ProjectRoot `
            -LanguageData $LanguageData `
            -ShowProgress

        $SpeedStepStatus = if ($SpeedTestResult.Status -eq 'OK') {
            'OK'
        }
        elseif ($SpeedTestResult.Status -eq 'WARN') {
            'WARN'
        }
        else {
            'ERROR'
        }

        $null = Stop-MTProfilerStep `
            -Step $SpeedStep `
            -Status $SpeedStepStatus `
            -Details $SpeedTestResult.ErrorMessage

        if ($SpeedTestResult.Status -eq 'OK') {
            $Speed = $SpeedTestResult.Result

            Add-MTNetworkReportKeyValue `
                -Lines $Lines `
                -Key (Get-MTText $LanguageData 'PING') `
                -Value (Format-MTNetworkReportText `
                    -Template "{0} ms" `
                    -Arguments @($Speed.PingMs))

            Add-MTNetworkReportKeyValue `
                -Lines $Lines `
                -Key (Get-MTText $LanguageData 'JITTER') `
                -Value (Format-MTNetworkReportText `
                    -Template "{0} ms" `
                    -Arguments @($Speed.JitterMs))

            Add-MTNetworkReportKeyValue `
                -Lines $Lines `
                -Key (Get-MTText $LanguageData 'DOWNLOAD') `
                -Value (Format-MTNetworkReportText `
                    -Template "{0} Mbps" `
                    -Arguments @($Speed.DownloadMbps))

            Add-MTNetworkReportKeyValue `
                -Lines $Lines `
                -Key (Get-MTText $LanguageData 'UPLOAD') `
                -Value (Format-MTNetworkReportText `
                    -Template "{0} Mbps" `
                    -Arguments @($Speed.UploadMbps))

            if ($null -ne $Speed.PacketLossPercent) {
                Add-MTNetworkReportKeyValue `
                    -Lines $Lines `
                    -Key (Get-MTText $LanguageData 'PACKET_LOSS') `
                    -Value (Format-MTNetworkReportText `
                        -Template "{0:N2} %" `
                        -Arguments @([double]$Speed.PacketLossPercent))
            }

            Add-MTNetworkReportKeyValue `
                -Lines $Lines `
                -Key (Get-MTText $LanguageData 'SPEEDTEST_SERVER') `
                -Value $Speed.ServerName

            Add-MTNetworkReportKeyValue `
                -Lines $Lines `
                -Key (Get-MTText $LanguageData 'SPEEDTEST_RESULT_URL') `
                -Value $Speed.ResultUrl
        }
        else {
            Add-MTNetworkReportKeyValue `
                -Lines $Lines `
                -Key (Get-MTText $LanguageData 'SPEEDTEST') `
                -Value $SpeedTestResult.ErrorMessage
        }
    }

    $FinalProfile = Stop-MTProfiler

    Add-MTNetworkReportSection `
        -Lines $Lines `
        -Title (Get-MTText $LanguageData "REPORT_PROFILER")

    Add-MTNetworkReportKeyValue `
        -Lines $Lines `
        -Key (Get-MTText $LanguageData "NETWORK_DURATION") `
        -Value (Format-MTNetworkReportText `
            -Template "{0:N2} s" `
            -Arguments @(([double]$FinalProfile.DurationMs / 1000)))

    foreach ($ProfileStep in @($FinalProfile.Steps)) {
        [void]$Lines.Add(
            (Format-MTNetworkReportText `
                -Template "{0,-12} {1,-7} {2,10:N2} ms {3}" `
                -Arguments @(
                    $ProfileStep.Name,
                    $ProfileStep.Status,
                    $ProfileStep.DurationMs,
                    $ProfileStep.Details
                ))
        )
    }

    # Write correlated artifacts only after all in-memory collection is complete.
    $Lines |
        Set-Content `
            -LiteralPath $TxtPath `
            -Encoding UTF8

    if ($null -ne $Topology) {
        $Topology |
            ConvertTo-Json -Depth 14 |
            Set-Content `
                -LiteralPath $TopologyPath `
                -Encoding UTF8
    }

    if ($null -ne $RuleEvaluation) {
        $RuleEvaluation |
            ConvertTo-Json -Depth 12 |
            Set-Content `
                -LiteralPath $RulesPath `
                -Encoding UTF8
    }

    if (
        $null -ne $SpeedTestResult -and
        $SpeedTestResult.Status -eq 'OK' -and
        $null -ne $SpeedTestResult.RawJson
    ) {
        $SpeedTestResult.RawJson |
            ConvertTo-Json -Depth 12 |
            Set-Content `
                -LiteralPath $SpeedTestPath `
                -Encoding UTF8
    }

    return [pscustomobject]@{
        RunId = $RunId
        ReportPath = $TxtPath
        TopologyPath = if ($null -ne $Topology) { $TopologyPath } else { $null }
        RulesPath = if ($null -ne $RuleEvaluation) { $RulesPath } else { $null }
        SpeedTestPath = if (
            $null -ne $SpeedTestResult -and
            $SpeedTestResult.Status -eq 'OK'
        ) { $SpeedTestPath } else { $null }
        SpeedTest = $SpeedTestResult
        Succeeded = ($null -ne $Topology)
    }
}
