function Format-MTDuration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [TimeSpan]$Duration,
        [Parameter(Mandatory)] [object]$LanguageData,
        [ValidateSet('Compact','Verbose')] [string]$Mode = 'Compact'
    )

    $day = Get-MTText $LanguageData 'TIME_DAY'
    $hour = Get-MTText $LanguageData 'TIME_HOUR'
    $minute = Get-MTText $LanguageData 'TIME_MINUTE'
    $second = Get-MTText $LanguageData 'TIME_SECOND'
    $millisecond = Get-MTText $LanguageData 'TIME_MILLISECOND'

    if ($Duration.TotalMilliseconds -lt 1000) { return '{0:N0} {1}' -f $Duration.TotalMilliseconds, $millisecond }
    if ($Duration.TotalSeconds -lt 60) { return '{0:N2} {1}' -f $Duration.TotalSeconds, $second }
    if ($Duration.TotalMinutes -lt 60) { return '{0} {1} {2:D2} {3}' -f [math]::Floor($Duration.TotalMinutes),$minute,$Duration.Seconds,$second }
    if ($Duration.TotalHours -lt 24) { return '{0} {1} {2:D2} {3} {4:D2} {5}' -f [math]::Floor($Duration.TotalHours),$hour,$Duration.Minutes,$minute,$Duration.Seconds,$second }
    return '{0} {1} {2:D2} {3} {4:D2} {5}' -f [math]::Floor($Duration.TotalDays),$day,$Duration.Hours,$hour,$Duration.Minutes,$minute
}
