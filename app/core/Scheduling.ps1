# MT 4.1 scheduling: pure validation separated from Windows task mutation.
function ConvertTo-MTWindowsArgument {
    param([AllowEmptyString()][string]$Value)
    if ($Value -match '[\x00-\x1f]') { throw 'MT41_ARGUMENT_INVALID' }
    '"' + [regex]::Replace([regex]::Replace($Value, '(\\*)"', '$1$1\"'), '(\\+)$', '$1$1') + '"'
}

function New-MTSchedulePlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ProjectRoot,
        [ValidateSet('maintenance','analysis','updates')][string]$Mode = 'maintenance',
        [ValidateSet('daily','weekly','startup')][string]$Frequency = 'daily',
        [string[]]$Times = @('03:00'),
        [string[]]$Days = @(),
        [string]$JsonDestination = '',
        [bool]$StartWhenAvailable = $true,
        [bool]$AllowBattery = $false,
        [bool]$RequireNetwork = $false
    )
    $Root = [IO.Path]::GetFullPath($ProjectRoot).TrimEnd('\')
    if ($Root -match '[\x00-\x1f"]' -or $Root.StartsWith('\\')) { throw 'MT41_ROOT_INVALID' }
    if ($Frequency -ne 'startup') {
        if ($Times.Count -eq 0 -or $Times.Count -gt 24) { throw 'MT41_TIME_INVALID' }
        foreach ($Time in $Times) { if ($Time -notmatch '^(?:[01]\d|2[0-3]):[0-5]\d$') { throw 'MT41_TIME_INVALID' } }
        if (@($Times | Select-Object -Unique).Count -ne $Times.Count) { throw 'MT41_TIME_INVALID' }
    }
    $AllowedDays = @('Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday')
    if ($Frequency -eq 'weekly') {
        if ($Days.Count -eq 0 -or @($Days | Where-Object { $_ -notin $AllowedDays }).Count -gt 0 -or @($Days | Select-Object -Unique).Count -ne $Days.Count) { throw 'MT41_DAY_INVALID' }
    } elseif ($Days.Count -gt 0) { throw 'MT41_DAY_INVALID' }
    if ($JsonDestination) {
        if ($JsonDestination -match '[\x00-\x1f"]' -or $JsonDestination -notmatch '^(?:[A-Za-z]:\\|\\\\[^\\]+\\[^\\]+)') { throw 'MT41_DESTINATION_INVALID' }
        $JsonDestination = [IO.Path]::GetFullPath($JsonDestination)
        if ($JsonDestination -eq $Root -or $JsonDestination.StartsWith($Root + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'MT41_DESTINATION_INVALID' }
    }
    $Args = '-ScheduledMode ' + $Mode
    if ($JsonDestination) { $Args += ' -JsonReportDestination ' + (ConvertTo-MTWindowsArgument $JsonDestination) }
    [pscustomobject]@{Root=$Root; Mode=$Mode; Frequency=$Frequency; Times=@($Times); Days=@($Days); JsonDestination=$JsonDestination; Executable=(Join-Path $Root 'MaintenanceToolkit.exe'); Arguments=$Args; StartWhenAvailable=$StartWhenAvailable; AllowBattery=$AllowBattery; RequireNetwork=$RequireNetwork}
}

function Write-MTScheduleEvent {
    param([string]$ProjectRoot,[string]$Operation,[string]$TaskName)
    $StatePath=Get-MTUpdateStatePath $ProjectRoot
    Initialize-MTProtectedDirectory $StatePath
    [pscustomobject]@{at=[DateTimeOffset]::Now.ToString('o');operation=$Operation;taskPath='\Kraugh\';taskName=$TaskName} |
        ConvertTo-Json -Compress | Add-Content -LiteralPath (Join-Path $StatePath 'schedule-events.jsonl') -Encoding UTF8 -ErrorAction Stop
}

function Get-MTStandaloneSchedule {
    param([Parameter(Mandatory)][string]$ProjectRoot)
    $Executable=Join-Path ([IO.Path]::GetFullPath($ProjectRoot).TrimEnd('\')) 'MaintenanceToolkit.exe'
    foreach($Name in @('Maintenance Toolkit - MSI Managed','Maintenance Toolkit - Standalone Managed')) {
        $Task=Get-ScheduledTask -TaskPath '\Kraugh\' -TaskName $Name -ErrorAction SilentlyContinue
        if(-not $Task){continue}
        if(@($Task.Actions).Count -ne 1 -or [string]$Task.Actions[0].Execute -ne $Executable) {
            if($Name -eq 'Maintenance Toolkit - Standalone Managed'){throw 'MT41_TASK_OWNERSHIP'}
            continue
        }
        $Info=Get-ScheduledTaskInfo -TaskPath '\Kraugh\' -TaskName $Name -ErrorAction Stop
        return [pscustomobject]@{TaskPath='\Kraugh\';TaskName=$Name;Task=$Task;LastRunTime=$Info.LastRunTime;LastTaskResult=$Info.LastTaskResult;NextRunTime=$Info.NextRunTime}
    }
    return $null
}

function Remove-MTStandaloneSchedule {
    param([Parameter(Mandatory)][string]$ProjectRoot,[Parameter(Mandatory)]$Management,[switch]$Confirmed)
    if(-not (Test-MTAdministrator)){throw 'MT41_ADMIN_REQUIRED'}
    if($Management.Status -ne 'Valid' -or $Management.Management -ne 'standalone'){throw 'MT41_MANAGEMENT_BLOCKED'}
    if(-not (Get-MTSelfUpdateConfiguration $ProjectRoot).CanInstall){throw 'MT41_MANAGEMENT_BLOCKED'}
    if(-not (Test-MTProtectedPath $ProjectRoot)){throw 'MT41_ROOT_UNPROTECTED'}
    if(-not $Confirmed){throw 'MT41_TASK_REMOVE_CONFIRM_REQUIRED'}
    $Schedule=Get-MTStandaloneSchedule $ProjectRoot
    if(-not $Schedule){throw 'MT41_TASK_NOT_FOUND'}
    Write-MTScheduleEvent $ProjectRoot 'remove_requested' $Schedule.TaskName
    Unregister-ScheduledTask -TaskPath $Schedule.TaskPath -TaskName $Schedule.TaskName -Confirm:$false -ErrorAction Stop
    Write-MTScheduleEvent $ProjectRoot 'removed' $Schedule.TaskName
    $Schedule
}

function Register-MTStandaloneSchedule {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Plan, [Parameter(Mandatory)]$Management, [switch]$ReplaceExisting)
    if (-not (Test-MTAdministrator)) { throw 'MT41_ADMIN_REQUIRED' }
    if ($Management.Status -ne 'Valid' -or $Management.Management -ne 'standalone') { throw 'MT41_MANAGEMENT_BLOCKED' }
    if (-not (Get-MTSelfUpdateConfiguration $Plan.Root).CanInstall) { throw 'MT41_MANAGEMENT_BLOCKED' }
    if (-not (Test-Path -LiteralPath $Plan.Executable -PathType Leaf)) { throw 'MT41_LAUNCHER_MISSING' }
    if (-not (Test-MTProtectedPath -Path $Plan.Root) -or -not (Test-MTProtectedPath -Path $Plan.Executable)) { throw 'MT41_ROOT_UNPROTECTED' }
    $TaskPath = '\Kraugh\'
    $TaskName = 'Maintenance Toolkit - Standalone Managed'
    $MsiTask = Get-ScheduledTask -TaskPath $TaskPath -TaskName 'Maintenance Toolkit - MSI Managed' -ErrorAction SilentlyContinue
    if ($MsiTask -and @($MsiTask.Actions).Count -eq 1 -and [string]$MsiTask.Actions[0].Execute -eq $Plan.Executable) { $TaskName = 'Maintenance Toolkit - MSI Managed' }
    $Existing = Get-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($Existing) {
        if (@($Existing.Actions).Count -ne 1 -or [string]$Existing.Actions[0].Execute -ne $Plan.Executable) { throw 'MT41_TASK_OWNERSHIP' }
        if (-not $ReplaceExisting) { throw 'MT41_TASK_EXISTS' }
    }
    $Triggers = @()
    if ($Plan.Frequency -eq 'startup') { $Triggers += New-ScheduledTaskTrigger -AtStartup }
    else {
        foreach ($Time in $Plan.Times) {
            $At = [datetime]::Today.Add([timespan]::Parse($Time))
            if ($Plan.Frequency -eq 'daily') { $Triggers += New-ScheduledTaskTrigger -Daily -At $At }
            else { $Triggers += New-ScheduledTaskTrigger -Weekly -DaysOfWeek $Plan.Days -At $At }
        }
    }
    $Action = New-ScheduledTaskAction -Execute $Plan.Executable -Argument $Plan.Arguments -WorkingDirectory $Plan.Root
    $Principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    $Settings = New-ScheduledTaskSettingsSet -StartWhenAvailable:$Plan.StartWhenAvailable -AllowStartIfOnBatteries:$Plan.AllowBattery -DontStopIfGoingOnBatteries:$Plan.AllowBattery -RunOnlyIfNetworkAvailable:$Plan.RequireNetwork -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Hours 4)
    $StatePath=Get-MTUpdateStatePath $Plan.Root
    Initialize-MTProtectedDirectory $StatePath
    Write-MTScheduleEvent $Plan.Root 'save_requested' $TaskName
    Register-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -Action $Action -Trigger $Triggers -Principal $Principal -Settings $Settings -Force:$ReplaceExisting | Out-Null
    Save-MTUpdateJson (Join-Path $StatePath 'last-schedule.json') ([pscustomobject]@{taskPath=$TaskPath;taskName=$TaskName;createdAt=[DateTimeOffset]::Now.ToString('o');plan=$Plan})
    Write-MTScheduleEvent $Plan.Root 'saved' $TaskName
    [pscustomobject]@{TaskPath=$TaskPath; TaskName=$TaskName; Plan=$Plan}
}

function Publish-MTSessionJson {
    param([Parameter(Mandatory)][string]$SessionPath, [string]$Destination)
    if (-not $Destination) { return [pscustomobject]@{Status='NotRequested';Files=0} }
    $Count = 0
    $Partial = $null
    try {
        $Target = Join-Path $Destination ([IO.Path]::GetFileName($SessionPath))
        New-Item -ItemType Directory -Path $Target -Force -ErrorAction Stop | Out-Null
        foreach ($File in @(Get-ChildItem -LiteralPath $SessionPath -Filter '*.json' -File -Recurse)) {
            $Relative = $File.FullName.Substring($SessionPath.TrimEnd('\').Length + 1)
            $Final = Join-Path $Target $Relative
            New-Item -ItemType Directory -Path (Split-Path -Parent $Final) -Force -ErrorAction Stop | Out-Null
            $Partial = $Final + '.' + [guid]::NewGuid().ToString('N') + '.partial'
            Copy-Item -LiteralPath $File.FullName -Destination $Partial -ErrorAction Stop
            Move-Item -LiteralPath $Partial -Destination $Final -ErrorAction Stop
            $Partial = $null
            $Count++
        }
        [pscustomobject]@{Status='Published';Files=$Count}
    } catch {
        if ($Partial -and (Test-Path -LiteralPath $Partial)) { Remove-Item -LiteralPath $Partial -Force -ErrorAction SilentlyContinue }
        [pscustomobject]@{Status='WARN';Files=$Count;ErrorCode='MT41_PUBLICATION_FAILED'}
    }
}

function Invoke-MTScheduleWizard {
    param([Parameter(Mandatory)][string]$ProjectRoot)
    try {
        $Management=Get-MTSelfUpdateConfiguration -ProjectRoot $ProjectRoot
        if ($Management.Status -ne 'Valid' -or $Management.Management -ne 'standalone') { throw 'MT41_MANAGEMENT_BLOCKED' }
        Write-Host (T 'MT41_TASK_ACTIONS')
        $Choice=Read-Host (T 'MT41_TASK_ACTION_PROMPT')
        if($Choice -eq '0' -or -not $Choice){return}
        if($Choice -in @('2','3')) {
            $Schedule=Get-MTStandaloneSchedule $ProjectRoot
            if(-not $Schedule){throw 'MT41_TASK_NOT_FOUND'}
            Write-Host (T 'MT41_TASK_INFO' @(($Schedule.TaskPath+$Schedule.TaskName),$Schedule.Task.State,$Schedule.LastRunTime,$Schedule.LastTaskResult,$Schedule.NextRunTime,$Schedule.Task.Actions[0].Arguments))
            if($Choice -eq '3' -and (Read-Host (T 'MT41_TASK_REMOVE_CONFIRM')) -ceq 'YES') {
                $null=Remove-MTStandaloneSchedule $ProjectRoot $Management -Confirmed
                Write-Host (T 'MT41_TASK_REMOVED')
            }
            return
        }
        if($Choice -ne '1'){throw 'MT41_MODE_INVALID'}
        Write-Host (T 'MT41_MODES')
        $ModeChoice=Read-Host (T 'MT41_MODE_PROMPT')
        $Mode=switch($ModeChoice) { '1' {'maintenance'} '2' {'analysis'} '3' {'updates'} default {throw 'MT41_MODE_INVALID'} }
        Write-Host (T 'MT41_FREQUENCIES')
        $FrequencyChoice=Read-Host (T 'MT41_FREQUENCY_PROMPT')
        $Frequency=switch($FrequencyChoice) { '1' {'daily'} '2' {'weekly'} '3' {'startup'} default {throw 'MT41_FREQUENCY_INVALID'} }
        $Times=@();$Days=@()
        if ($Frequency -ne 'startup') { $Times=@((Read-Host (T 'MT41_TIMES_PROMPT')).Split(',') | ForEach-Object {$_.Trim()}) }
        if ($Frequency -eq 'weekly') {
            $DayNames=@('Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday')
            foreach($Number in (Read-Host (T 'MT41_DAYS_PROMPT')).Split(',')) {
                if ($Number.Trim() -notmatch '^[1-7]$') { throw 'MT41_DAY_INVALID' }
                $Days += $DayNames[[int]$Number.Trim()-1]
            }
        }
        $Destination=Read-Host (T 'MT41_DESTINATION_PROMPT')
        $Missed=(Read-Host (T 'MT41_TASK_MISSED_PROMPT')) -cne 'NO'
        $Battery=(Read-Host (T 'MT41_TASK_BATTERY_PROMPT')) -ceq 'YES'
        $Network=(Read-Host (T 'MT41_TASK_NETWORK_PROMPT')) -ceq 'YES'
        $Plan=New-MTSchedulePlan -ProjectRoot $ProjectRoot -Mode $Mode -Frequency $Frequency -Times $Times -Days $Days -JsonDestination $Destination -StartWhenAvailable $Missed -AllowBattery $Battery -RequireNetwork $Network
        Write-Host (T 'MT41_SCHEDULE_SUMMARY' @($Plan.Mode,$Plan.Frequency,($Plan.Times -join ','),($Plan.Days -join ','),$Plan.JsonDestination,$Plan.Arguments))
        Write-Host (T 'MT41_TASK_CONDITIONS' @($Missed,$Battery,$Network))
        if ($Mode -eq 'maintenance') {
            foreach($Module in $Catalog) { if(Get-IniBool $Config 'Modules' $Module.Key $false) { Write-Host $Module.Name } }
        }
        if ((Read-Host (T 'MT41_CONFIRM')) -cne 'YES') { return }
        $Replace=(Read-Host (T 'MT41_REPLACE_CONFIRM')) -ceq 'YES'
        $Result=Register-MTStandaloneSchedule -Plan $Plan -Management $Management -ReplaceExisting:$Replace
        Write-Host (T 'MT41_TASK_CREATED' @($Result.TaskPath+$Result.TaskName))
    } catch {
        $Code=$_.Exception.Message
        if ($Code -notmatch '^MT41_[A-Z_]+$') { $Code='MT41_TASK_FAILED' }
        Write-Host (T $Code) -ForegroundColor Yellow
    }
}
