. "$PSScriptRoot\00_common.ps1"
. "$PSScriptRoot\oem\HPImageAssistant.ps1"

$Module = "OEM"
$Manufacturer = (Get-CimInstance Win32_ComputerSystem).Manufacturer.Trim()
$Interactive = $env:MT_INTERACTIVE -eq "1"

Write-Main (Get-MTRuntimeText "OEM_DETECTED" @($Manufacturer))

if ($Manufacturer -match "Dell") {
    $Candidates = @(
        "$env:ProgramFiles\Dell\CommandUpdate\dcu-cli.exe",
        "${env:ProgramFiles(x86)}\Dell\CommandUpdate\dcu-cli.exe"
    )
    $Tool = $Candidates |
        Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
        Select-Object -First 1

    if (-not $Tool) {
        Set-ModuleResult `
            (Get-MTRuntimeText "MODULE_OEM") `
            "SKIP" `
            (Get-MTRuntimeText "OEM_DELL_NOT_INSTALLED")
        exit 10
    }

    try {
        $null = Get-MTVerifiedRestorePoint -Manufacturer "Dell"
    }
    catch {
        $Detail = $_.Exception.Message
        Write-ErrorLog $Detail $Module
        Set-ModuleResult (Get-MTRuntimeText "MODULE_OEM") "ERROR" $Detail
        exit 1
    }

    $Result = Invoke-LoggedProcess `
        -FilePath $Tool `
        -ArgumentList @(
            "/applyUpdates",
            "-silent",
            "-reboot=disable",
            "-autoSuspendBitLocker=enable"
        ) `
        -Label "Dell Command Update" `
        -Module $Module `
        -SuccessCodes @(0, 1, 500) `
        -TimeoutSeconds 7200

    if ($Result -in @(0, 1, 500)) {
        $NeedsReboot = $Result -eq 1
        $Status = if ($NeedsReboot) { "WARN" } else { "OK" }
        $Detail = Get-MTRuntimeText "OEM_DELL_RESULT" @($Result)
        Set-ModuleResult `
            (Get-MTRuntimeText "MODULE_OEM") `
            $Status `
            $Detail `
            $NeedsReboot
        if ($NeedsReboot) { exit 20 }
        exit 0
    }

    Set-ModuleResult `
        (Get-MTRuntimeText "MODULE_OEM") `
        "ERROR" `
        (Get-MTRuntimeText "OEM_DELL_RESULT" @($Result))
    exit 1
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
    Set-ModuleResult `
        (Get-MTRuntimeText "MODULE_OEM") `
        "SKIP" `
        (Get-MTRuntimeText "OEM_LENOVO_NOT_CONFIGURED")
    exit 10
}

$Detail = Get-MTRuntimeText "OEM_UNSUPPORTED" @($Manufacturer)
Write-Skip $Detail $Module
Set-ModuleResult (Get-MTRuntimeText "MODULE_OEM") "SKIP" $Detail
exit 10
