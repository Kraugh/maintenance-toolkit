. "$PSScriptRoot\00_common.ps1"
. "$PSScriptRoot\oem\HPImageAssistant.ps1"
. "$PSScriptRoot\oem\DellCommandUpdate.ps1"

$Module = "OEM"
$Manufacturer = (Get-CimInstance Win32_ComputerSystem).Manufacturer.Trim()
$Interactive = $env:MT_INTERACTIVE -eq "1"

Write-Main (Get-MTRuntimeText "OEM_DETECTED" @($Manufacturer))

if ($Manufacturer -match "Dell") {
    $Status = [ordered]@{
        attempted = $true
        manufacturer = "Dell"
        detectedAt = (Get-Date).ToString("o")
        status = "analyzing"
        tool = $null
        biosUpdate = $null
        updates = @()
        rebootRequired = $false
        errorCode = $null
    }

    try {
        $InstalledByMt = $false
        $Tool = Get-MTDellCommandUpdate
        if (-not $Tool) {
            $Status.status = "preparing_tool"
            $Status.tool = [ordered]@{
                name = "Dell Command Update"
                version = $null
                path = $null
                installationStatus = "required"
            }
            $null = Get-MTVerifiedRestorePoint -Manufacturer "Dell"
            $Tool = Install-MTDellCommandUpdate
            $InstalledByMt = $true
        }

        $Status.tool = [ordered]@{
            name = "Dell Command Update"
            version = [string](Get-Item -LiteralPath $Tool).VersionInfo.FileVersion
            path = $Tool
            installationStatus = if ($InstalledByMt) {
                "installed_by_mt"
            }
            else {
                "already_installed"
            }
        }
        $BiosScan = Invoke-MTDcuScan -Executable $Tool -UpdateType "bios" -Purpose "bios"
        $SafeScan = Invoke-MTDcuScan `
            -Executable $Tool `
            -UpdateType "firmware,driver,application,utility,others" `
            -Purpose "safe"

        $Bios = @($BiosScan.Updates) | Select-Object -First 1
        $CurrentBios = (Get-CimInstance Win32_BIOS).SMBIOSBIOSVersion
        if ($null -ne $Bios) {
            $Status.biosUpdate = [ordered]@{
                status = "urgent_action_required"
                severity = if ([string]::IsNullOrWhiteSpace($Bios.severity)) { "unknown" } else { ([string]$Bios.severity).ToLowerInvariant() }
                currentVersion = [string]$CurrentBios
                targetVersion = [string]$Bios.targetVersion
                releaseId = [string]$Bios.id
                name = [string]$Bios.name
                automaticInstall = $false
                reason = "blocked_by_unattended_bios_policy"
                detectedAt = (Get-Date).ToString("o")
            }
            Write-WarnLog (Get-MTRuntimeText "OEM_DELL_BIOS_URGENT" @($Bios.targetVersion, $CurrentBios)) $Module
        }

        $Installable = @($SafeScan.Updates)
        $ApplyCode = 500
        $Status.updates = @()
        if ($Installable.Count -gt 0) {
            $null = Get-MTVerifiedRestorePoint -Manufacturer "Dell"
            $ApplyResult = Invoke-MTDcuSafeUpdates -Executable $Tool
            $ApplyCode = [int]$ApplyResult.ExitCode
            $Status.rebootRequired = $ApplyCode -eq 1
            if ($ApplyCode -notin @(0, 1, 500)) {
                throw (Get-MTRuntimeText "OEM_DELL_UPDATES_FAILED" @($ApplyCode))
            }

            try {
                if ($ApplyResult.SelfUpdateStarted) {
                    Write-Main (Get-MTRuntimeText "OEM_DELL_SELF_UPDATE_WAIT")
                    $UpdatedTool = Wait-MTDcuSelfUpdate `
                        -PreviousVersion $ApplyResult.PreviousToolVersion `
                        -TimeoutSeconds 900
                    $Tool = $UpdatedTool.Executable
                    $Status.tool.version = $UpdatedTool.Version
                    $Status.tool.path = $UpdatedTool.Executable
                    Write-Main (
                        Get-MTRuntimeText "OEM_DELL_SELF_UPDATE_COMPLETED" @(
                            $ApplyResult.PreviousToolVersion,
                            $UpdatedTool.Version
                        )
                    )
                }

                $VerificationScan = Invoke-MTDcuScan `
                    -Executable $Tool `
                    -UpdateType "firmware,driver,application,utility,others" `
                    -Purpose "verification"
                $RemainingIds = @(
                    $VerificationScan.Updates |
                        ForEach-Object { [string]$_.id }
                )
                $Status.updates = @(
                    foreach ($Update in $Installable) {
                        [pscustomobject][ordered]@{
                            id = $Update.id
                            name = $Update.name
                            type = $Update.type
                            currentVersion = $Update.currentVersion
                            targetVersion = $Update.targetVersion
                            severity = $Update.severity
                            status = if ($RemainingIds -contains [string]$Update.id) {
                                "still_applicable"
                            }
                            else {
                                "installed"
                            }
                            rebootRequired = $Update.rebootRequired
                        }
                    }
                )
            }
            catch {
                $Status.updates = @(
                    foreach ($Update in $Installable) {
                        [pscustomobject][ordered]@{
                            id = $Update.id
                            name = $Update.name
                            type = $Update.type
                            currentVersion = $Update.currentVersion
                            targetVersion = $Update.targetVersion
                            severity = $Update.severity
                            status = "verification_failed"
                            rebootRequired = $Update.rebootRequired
                        }
                    }
                )
                throw
            }
        }

        $NeedsReboot = [bool]$Status.rebootRequired
        $StillApplicable = @(
            $Status.updates |
                Where-Object { $_.status -eq "still_applicable" }
        )
        $Status.status = if ($null -ne $Bios) {
            "action_required"
        }
        elseif ($NeedsReboot) {
            "restart_required"
        }
        elseif ($StillApplicable.Count -gt 0) {
            "verification_failed"
        }
        else {
            "ok"
        }
        Save-MTOemStatus -Status $Status

        if ($null -ne $Bios) {
            $Detail = Get-MTRuntimeText "OEM_DELL_BIOS_URGENT" @($Bios.targetVersion, $CurrentBios)
            Set-ModuleResult (Get-MTRuntimeText "MODULE_OEM") "WARN" $Detail $NeedsReboot
            exit 20
        }

        $Detail = if ($Installable.Count -eq 0) {
            Get-MTRuntimeText "OEM_DELL_NO_UPDATES"
        }
        elseif ($StillApplicable.Count -gt 0) {
            Get-MTRuntimeText "OEM_DELL_VERIFICATION_INCOMPLETE" @(
                $Installable.Count,
                $StillApplicable.Count,
                $ApplyCode
            )
        }
        else {
            Get-MTRuntimeText "OEM_DELL_UPDATES_COMPLETED" @($Installable.Count, $ApplyCode)
        }
        $HasWarning = $NeedsReboot -or $StillApplicable.Count -gt 0
        Set-ModuleResult `
            (Get-MTRuntimeText "MODULE_OEM") `
            $(if ($HasWarning) { "WARN" } else { "OK" }) `
            $Detail `
            $NeedsReboot
        if ($HasWarning) { exit 20 }
        exit 0
    }
    catch {
        $Status.status = "error"
        $Status.errorCode = $_.Exception.Message
        Save-MTOemStatus -Status $Status
        Write-ErrorLog $_.Exception.Message $Module
        Set-ModuleResult (Get-MTRuntimeText "MODULE_OEM") "ERROR" $_.Exception.Message
        exit 1
    }
}

if ($Manufacturer -match "HP|Hewlett") {
    $Status = [ordered]@{
        attempted = $true
        manufacturer = "HP"
        detectedAt = (Get-Date).ToString("o")
        status = "analyzing"
        tool = $null
        biosUpdate = $null
        updates = @()
        errorCode = $null
    }

    try {
        $Tool = Get-MTHpImageAssistant
        $Status.tool = [ordered]@{
            name = "HP Image Assistant"
            version = (Get-Item -LiteralPath $Tool).VersionInfo.FileVersion
            path = $Tool
        }

        $AllAnalysis = Invoke-MTHpia `
            -Executable $Tool `
            -Action "List" `
            -Category "All" `
            -TimeoutSeconds 1800
        $BiosAnalysis = Invoke-MTHpia `
            -Executable $Tool `
            -Action "List" `
            -Category "BIOS" `
            -TimeoutSeconds 1800

        if ($AllAnalysis.ExitCode -notin @(0, 256, 257)) {
            throw (Get-MTRuntimeText "OEM_HP_ANALYSIS_FAILED" @($AllAnalysis.ExitCode))
        }
        if ($BiosAnalysis.ExitCode -notin @(0, 256, 257)) {
            throw (Get-MTRuntimeText "OEM_HP_ANALYSIS_FAILED" @($BiosAnalysis.ExitCode))
        }

        $AllRecommendations = @(Get-MTHpiaRecommendations -Operation $AllAnalysis)
        $BiosRecommendations = @(Get-MTHpiaRecommendations -Operation $BiosAnalysis)
        $BiosIds = @($BiosRecommendations | ForEach-Object { [string]$_.SoftPaqID })

        $CachePath = Join-Path `
            $env:ProgramData `
            "Kraugh\MaintenanceToolkit\Tools\HPIA\suppressed-softpaqs.json"
        $Cache = @(Read-MTHpiaSuppressionCache -Path $CachePath)

        $Installable = @(
            $AllRecommendations |
                Where-Object {
                    [string]$_.SSMCompliant -eq "True" -and
                    [string]$_.SoftPaqID -notin $BiosIds
                } |
                Where-Object {
                    $Recommendation = $_
                    @(
                        $Cache |
                            Where-Object {
                                $_.softPaqId -eq [string]$Recommendation.SoftPaqID -and
                                $_.targetVersion -eq [string]$Recommendation.RecommendationValue
                            }
                    ).Count -eq 0
                }
        )

        foreach ($Suppressed in $Cache) {
            if (@($AllRecommendations | Where-Object {
                $_.SoftPaqID -eq $Suppressed.softPaqId -and
                $_.RecommendationValue -eq $Suppressed.targetVersion
            }).Count -gt 0) {
                Write-WarnLog `
                    (Get-MTRuntimeText "OEM_HP_ALREADY_INSTALLED" @($Suppressed.softPaqId)) `
                    $Module
            }
        }

        if ($Installable.Count -gt 0) {
            $null = Get-MTVerifiedRestorePoint -Manufacturer "HP"
            $SPListPath = Join-Path $env:MT_SESSION_DIR "hp-approved-softpaqs.txt"
            $SoftPaqNumbers = @(
                $Installable |
                    ForEach-Object { ([string]$_.SoftPaqID) -replace '^sp', '' }
            )
            [IO.File]::WriteAllLines(
                $SPListPath,
                $SoftPaqNumbers,
                [Text.Encoding]::ASCII
            )

            $Install = Invoke-MTHpia `
                -Executable $Tool `
                -Action "Install" `
                -Category "All" `
                -SPListPath $SPListPath `
                -TimeoutSeconds 7200

            $InstalledRecommendations = @(Get-MTHpiaRecommendations -Operation $Install)
            $UpdateResults = foreach ($Recommendation in $InstalledRecommendations) {
                $Remediation = $Recommendation.Remediation
                [pscustomobject][ordered]@{
                    softPaqId = [string]$Recommendation.SoftPaqID
                    name = [string]$Recommendation.Name
                    targetVersion = [string]$Recommendation.RecommendationValue
                    severity = [string]$Recommendation.Severity
                    status = [string]$Remediation.Status
                    returnCode = [string]$Remediation.ReturnCode
                    returnDescription = [string]$Remediation.ReturnDescription
                }
            }
            $Status.updates = @($UpdateResults)

            $NewSuppressions = @(
                $UpdateResults |
                    Where-Object {
                        $_.returnCode -eq "259" -or
                        $_.returnDescription -match "installed already"
                    } |
                    ForEach-Object {
                        [pscustomobject][ordered]@{
                            softPaqId = $_.softPaqId
                            targetVersion = $_.targetVersion
                            reason = "already_installed_or_newer"
                            detectedAt = (Get-Date).ToString("o")
                        }
                    }
            )
            if ($NewSuppressions.Count -gt 0) {
                $Cache = @($Cache) + @($NewSuppressions)
                $Cache = @(
                    $Cache |
                        Sort-Object softPaqId,targetVersion -Unique
                )
                Write-MTHpiaSuppressionCache -Path $CachePath -Entries $Cache
            }

            if ($Install.ExitCode -notin @(0, 256, 257, 3010, 3011)) {
                throw (Get-MTRuntimeText "OEM_HP_UPDATES_FAILED" @($Install.ExitCode))
            }
        }

        $CurrentBios = (Get-CimInstance Win32_BIOS).SMBIOSBIOSVersion
        $Bios = $BiosRecommendations | Select-Object -First 1
        $BiosNeedsReboot = $false
        $BiosFailure = $false

        if ($null -ne $Bios) {
            $Status.biosUpdate = [ordered]@{
                status = "urgent_action_required"
                severity = ([string]$Bios.Severity).ToLowerInvariant()
                currentVersion = [string]$CurrentBios
                targetVersion = [string]$Bios.RecommendationValue
                softPaqId = [string]$Bios.SoftPaqID
                releaseNotesUrl = "https://$([string]$Bios.ReleaseNotesUrl)"
                automaticInstall = $false
                reason = "blocked_by_unattended_bios_policy"
                detectedAt = (Get-Date).ToString("o")
            }

            $UrgentDetail = Get-MTRuntimeText "OEM_HP_BIOS_URGENT" @(
                [string]$Bios.RecommendationValue,
                [string]$CurrentBios
            )
            Write-WarnLog $UrgentDetail $Module

            if ($Interactive) {
                Write-Host ""
                Write-Host "============================================================" -ForegroundColor Red
                Write-Host (Get-MTRuntimeText "OEM_HP_BIOS_INTERACTIVE_TITLE") -ForegroundColor Red
                Write-Host "============================================================" -ForegroundColor Red
                Write-Host (Get-MTRuntimeText "OEM_HP_BIOS_INTERACTIVE_WARNING") -ForegroundColor Yellow
                Write-Host (Get-MTRuntimeText "OEM_HP_BIOS_CURRENT" @($CurrentBios))
                Write-Host (Get-MTRuntimeText "OEM_HP_BIOS_AVAILABLE" @(
                    [string]$Bios.RecommendationValue,
                    [string]$Bios.SoftPaqID
                ))
                Write-Host ""

                $Token = Get-MTRuntimeText "OEM_HP_BIOS_CONFIRM_TOKEN"
                $Choice = Read-Host (Get-MTRuntimeText "OEM_HP_BIOS_CONFIRM" @($Token))
                if ($Choice -ceq $Token) {
                    if (Test-MTPendingReboot) {
                        $Status.biosUpdate.status = "blocked_pending_reboot"
                        $Status.biosUpdate.reason = "pending_reboot"
                        Write-WarnLog `
                            (Get-MTRuntimeText "OEM_HP_BIOS_PENDING_REBOOT") `
                            $Module
                    }
                    else {
                        $null = Get-MTVerifiedRestorePoint -Manufacturer "HP"
                        Suspend-MTBitLockerForBiosUpdate
                        $BiosListPath = Join-Path $env:MT_SESSION_DIR "hp-approved-bios.txt"
                        [IO.File]::WriteAllLines(
                            $BiosListPath,
                            @(([string]$Bios.SoftPaqID -replace '^sp', '')),
                            [Text.Encoding]::ASCII
                        )

                        Write-WarnLog `
                            (Get-MTRuntimeText "OEM_HP_BIOS_STARTING") `
                            $Module
                        $BiosInstall = Invoke-MTHpia `
                            -Executable $Tool `
                            -Action "Install" `
                            -Category "BIOS" `
                            -SPListPath $BiosListPath `
                            -TimeoutSeconds 3600

                        if ($BiosInstall.ExitCode -eq 3010) {
                            $Status.biosUpdate.status = "restart_required"
                            $Status.biosUpdate.reason = $null
                            $BiosNeedsReboot = $true
                            Write-WarnLog `
                                (Get-MTRuntimeText "OEM_HP_BIOS_PREPARED") `
                                $Module
                        }
                        elseif ($BiosInstall.ExitCode -eq 0) {
                            $Status.biosUpdate.status = "completed"
                            $Status.biosUpdate.reason = $null
                            Write-Ok `
                                (Get-MTRuntimeText "OEM_HP_BIOS_COMPLETED") `
                                $Module
                        }
                        else {
                            $Status.biosUpdate.status = "error"
                            $Status.biosUpdate.reason = "hpia_exit_code_$($BiosInstall.ExitCode)"
                            $BiosFailure = $true
                            Write-ErrorLog `
                                (Get-MTRuntimeText "OEM_HP_BIOS_FAILED" @($BiosInstall.ExitCode)) `
                                $Module
                        }
                    }
                }
                else {
                    $Status.biosUpdate.status = "deferred_by_user"
                    $Status.biosUpdate.reason = "deferred_by_user"
                    Write-WarnLog (Get-MTRuntimeText "OEM_HP_BIOS_DEFERRED") $Module
                }
            }
        }

        $Status.status = if ($BiosFailure) {
            "error"
        }
        elseif ($null -ne $Bios -and $Status.biosUpdate.status -ne "completed") {
            "action_required"
        }
        else {
            "ok"
        }
        Save-MTOemStatus -Status $Status

        if ($BiosFailure) {
            $Detail = Get-MTRuntimeText "OEM_HP_BIOS_FAILED" @("see_report")
            Set-ModuleResult (Get-MTRuntimeText "MODULE_OEM") "ERROR" $Detail
            exit 1
        }

        if ($null -ne $Bios -and $Status.biosUpdate.status -ne "completed") {
            $Detail = Get-MTRuntimeText "OEM_HP_BIOS_URGENT" @(
                [string]$Bios.RecommendationValue,
                [string]$CurrentBios
            )
            Set-ModuleResult `
                (Get-MTRuntimeText "MODULE_OEM") `
                "WARN" `
                $Detail `
                $BiosNeedsReboot
            exit 20
        }

        $CompletedCount = @($Status.updates | Where-Object status -eq "INSTALL_COMPLETED").Count
        $SkippedCount = @($Cache).Count
        $Detail = if ($Installable.Count -eq 0) {
            Get-MTRuntimeText "OEM_HP_NO_UPDATES"
        }
        else {
            Get-MTRuntimeText "OEM_HP_UPDATES_COMPLETED" @($CompletedCount, $SkippedCount)
        }
        Set-ModuleResult `
            (Get-MTRuntimeText "MODULE_OEM") `
            $(if ($BiosNeedsReboot) { "WARN" } else { "OK" }) `
            $Detail `
            $BiosNeedsReboot
        if ($BiosNeedsReboot) { exit 20 }
        exit 0
    }
    catch {
        $Status.status = "error"
        $Status.errorCode = $_.Exception.Message
        Save-MTOemStatus -Status $Status
        Write-ErrorLog $_.Exception.Message $Module
        Set-ModuleResult `
            (Get-MTRuntimeText "MODULE_OEM") `
            "ERROR" `
            $_.Exception.Message
        exit 1
    }
}

if ($Manufacturer -match "Lenovo") {
    Save-MTOemStatus -Status ([ordered]@{
        attempted = $true
        manufacturer = "Lenovo"
        detectedAt = (Get-Date).ToString("o")
        status = "skipped"
        reason = "repository_not_configured"
        tool = $null
        biosUpdate = $null
        updates = @()
        errorCode = $null
    })
    Set-ModuleResult `
        (Get-MTRuntimeText "MODULE_OEM") `
        "SKIP" `
        (Get-MTRuntimeText "OEM_LENOVO_NOT_CONFIGURED")
    exit 10
}

$Detail = Get-MTRuntimeText "OEM_UNSUPPORTED" @($Manufacturer)
Save-MTOemStatus -Status ([ordered]@{
    attempted = $true
    manufacturer = $Manufacturer
    detectedAt = (Get-Date).ToString("o")
    status = "skipped"
    reason = "unsupported_manufacturer"
    tool = $null
    biosUpdate = $null
    updates = @()
    errorCode = $null
})
Write-Skip $Detail $Module
Set-ModuleResult (Get-MTRuntimeText "MODULE_OEM") "SKIP" $Detail
exit 10
