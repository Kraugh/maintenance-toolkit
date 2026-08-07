function New-NDRuleResult {
    param(
        [string]$Id,
        [ValidateSet("Info","Success","Warning","Critical")][string]$Severity,
        [bool]$Triggered,
        [string]$TitleKey,
        [string]$MessageKey,
        [object]$Evidence=$null
    )
    [pscustomobject]@{
        Id=$Id; Severity=$Severity; Triggered=$Triggered
        TitleKey=$TitleKey; MessageKey=$MessageKey; Evidence=$Evidence
    }
}

function Invoke-NDRules {
    param(
        [Parameter(Mandatory)][object]$Topology,
        [Parameter(Mandatory)][object]$RulesConfiguration
    )
    $results=New-Object System.Collections.ArrayList
    foreach($rule in $RulesConfiguration.Rules){
        if(-not $rule.Enabled){continue}
        $r=$null
        switch([string]$rule.Condition){
            "NoDefaultRoute" {
                $r=New-NDRuleResult $rule.Id $rule.Severity ($Topology.Summary.DefaultRouteCount -eq 0) "NET001_TITLE" "NET001_MESSAGE" ([pscustomobject]@{DefaultRouteCount=$Topology.Summary.DefaultRouteCount})
            }
            "MultipleDefaultRoutes" {
                $r=New-NDRuleResult $rule.Id $rule.Severity ($Topology.Summary.DefaultRouteCount -gt 1) "NET002_TITLE" "NET002_MESSAGE" ([pscustomobject]@{DefaultRouteCount=$Topology.Summary.DefaultRouteCount;DefaultRoutes=@($Topology.DefaultRoutes)})
            }
            "VPNWithoutRoutes" {
                $r=New-NDRuleResult $rule.Id $rule.Severity (($Topology.Summary.ActiveVPNCount -gt 0)-and($Topology.Summary.VPNRouteCount -eq 0)) "VPN001_TITLE" "VPN001_MESSAGE" ([pscustomobject]@{ActiveVPNCount=$Topology.Summary.ActiveVPNCount;VPNRouteCount=$Topology.Summary.VPNRouteCount})
            }
            "MultipleActiveVPNs" {
                $r=New-NDRuleResult $rule.Id $rule.Severity ($Topology.Summary.ActiveVPNCount -gt 1) "VPN002_TITLE" "VPN002_MESSAGE" ([pscustomobject]@{ActiveVPNCount=$Topology.Summary.ActiveVPNCount;ActiveVPNAdapters=@($Topology.ActiveVPNAdapters)})
            }
            "AmbiguousPhysicalBackend" {
                $count = @(
                    $Topology.EffectivePath.PhysicalBackendCandidates
                ).Count

                $source = [string]$Topology.EffectivePath.PhysicalBackendSource

                $triggered = (
                    $count -gt 1 -and
                    $source -ne "Get-VMSwitch"
                )

                $r = New-NDRuleResult `
                    $rule.Id `
                    $rule.Severity `
                    $triggered `
                    "TOP001_TITLE" `
                    "TOP001_MESSAGE" `
                    ([pscustomobject]@{
                        CandidateCount = $count
                        Source = $source
                        Candidates = @(
                            $Topology.EffectivePath.PhysicalBackendCandidates
                        )
                    })
            }
            "VirtualRoutingInterface" {
                $logical=$Topology.EffectivePath.LogicalAdapter
                $r=New-NDRuleResult $rule.Id $rule.Severity (($null -ne $logical)-and[bool]$logical.IsVirtual) "TOP002_TITLE" "TOP002_MESSAGE" $logical
            }
            "SplitTunnelCandidate" {
                $r=New-NDRuleResult $rule.Id $rule.Severity ($Topology.Summary.RoutingModeCandidate -eq "SplitTunnelCandidate") "VPN003_TITLE" "VPN003_MESSAGE" ([pscustomobject]@{VPNSpecificRouteCount=$Topology.Summary.VPNSpecificRouteCount})
            }
            "FullTunnelCandidate" {
                $r=New-NDRuleResult $rule.Id $rule.Severity ($Topology.Summary.RoutingModeCandidate -eq "FullTunnelCandidate") "VPN004_TITLE" "VPN004_MESSAGE" ([pscustomobject]@{VPNDefaultRoutes=@($Topology.VPNRoutes|Where-Object DestinationPrefix -eq "0.0.0.0/0")})
            }
        }
        if($null -ne $r){[void]$results.Add($r)}
    }
    [pscustomobject]@{
        EvaluatedAt=(Get-Date).ToString("o")
        RuleCount=$results.Count
        TriggeredCount=@($results|Where-Object Triggered).Count
        Results=@($results)
        Triggered=@($results|Where-Object Triggered)
    }
}
