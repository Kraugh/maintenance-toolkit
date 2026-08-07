# Imported/generalized from NDP 0.0.19-RC.
function Start-MTProfiler {
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    $script:MTProfiler = [pscustomobject]@{
        Name = $Name
        Started = (Get-Date)
        Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        Steps = New-Object System.Collections.ArrayList
    }

    return $script:MTProfiler
}

function Start-MTProfilerStep {
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    return [pscustomobject]@{
        Name = $Name
        Started = (Get-Date)
        Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    }
}

function Stop-MTProfilerStep {
    param(
        [Parameter(Mandatory)]
        [object]$Step,
        [string]$Status = "OK",
        [string]$Details = ""
    )

    $Step.Stopwatch.Stop()

    $result = [pscustomobject]@{
        Name = $Step.Name
        Started = $Step.Started
        Finished = (Get-Date)
        DurationMs = [math]::Round(
            [double]$Step.Stopwatch.Elapsed.TotalMilliseconds,
            2
        )
        Status = $Status
        Details = $Details
    }

    if ($null -ne $script:MTProfiler) {
        [void]$script:MTProfiler.Steps.Add($result)
    }

    return $result
}

function Stop-MTProfiler {
    if ($null -eq $script:MTProfiler) {
        return $null
    }

    $script:MTProfiler.Stopwatch.Stop()

    # PowerShell 5.1 can fail when a generic collection is expanded
    # directly inside a PSCustomObject hashtable. Copy every item first.
    $stepSnapshot = @(
        foreach ($item in $script:MTProfiler.Steps) {
            $item
        }
    )

    $finished = Get-Date
    $duration = [math]::Round(
        [double]$script:MTProfiler.Stopwatch.Elapsed.TotalMilliseconds,
        2
    )

    $profileResult = [pscustomobject]@{
        Name = [string]$script:MTProfiler.Name
        Started = $script:MTProfiler.Started
        Finished = $finished
        DurationMs = $duration
        Steps = $stepSnapshot
    }

    $script:MTProfiler = $null
    return $profileResult
}
