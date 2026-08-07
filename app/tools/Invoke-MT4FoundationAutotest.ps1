param(
    [string]$ProjectRoot = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Errors = New-Object System.Collections.Generic.List[string]
$Warnings = New-Object System.Collections.Generic.List[string]

function Add-MT4AutotestError {
    param([string]$Message)
    $Errors.Add($Message)
}

function Test-MT4Json {
    param([string]$Path)

    try {
        Get-Content -LiteralPath $Path -Raw -Encoding UTF8 |
            ConvertFrom-Json |
            Out-Null
    }
    catch {
        Add-MT4AutotestError (
            'Invalid JSON {0}: {1}' -f $Path, $_.Exception.Message
        )
    }
}

function Test-MT4PowerShellSyntax {
    param([string]$Path)

    $Tokens = $null
    $ParseErrors = $null

    [void][System.Management.Automation.Language.Parser]::ParseFile(
        $Path,
        [ref]$Tokens,
        [ref]$ParseErrors
    )

    foreach ($ParseError in $ParseErrors) {
        Add-MT4AutotestError (
            'PowerShell parse error in {0}: {1}' -f
            $Path,
            $ParseError.Message
        )
    }
}

$Required = @(
    'app/core/Bootstrap.ps1',
    'app/core/Settings.ps1',
    'app/core/Localization.ps1',
    'app/core/Formatters.ps1',
    'app/core/Logging.ps1',
    'app/core/Renderer.ps1',
    'app/core/LegacyIni.ps1',
    'app/core/Results.ps1',
    'app/core/ProcessRunner.ps1',
    'app/modules/00_common.ps1',
    'config/settings.json',
    'config/modules.json',
    'config/version.json',
    'languages/en-US.json',
    'languages/it-IT.json',
    'themes/default.json'
)

foreach ($RelativePath in $Required) {
    if (-not (Test-Path -LiteralPath (Join-Path $ProjectRoot $RelativePath))) {
        Add-MT4AutotestError ('Missing: {0}' -f $RelativePath)
    }
}

Get-ChildItem -LiteralPath (Join-Path $ProjectRoot 'config') -Filter *.json -File |
    ForEach-Object { Test-MT4Json $_.FullName }

Get-ChildItem -LiteralPath (Join-Path $ProjectRoot 'languages') -Filter *.json -File |
    ForEach-Object { Test-MT4Json $_.FullName }

Test-MT4Json (Join-Path $ProjectRoot 'themes/default.json')

Get-ChildItem -LiteralPath (Join-Path $ProjectRoot 'app') -Filter *.ps1 -File -Recurse |
    ForEach-Object { Test-MT4PowerShellSyntax $_.FullName }

Test-MT4PowerShellSyntax (Join-Path $ProjectRoot 'app/modules/00_common.ps1')

try {
    $English = Get-Content `
        (Join-Path $ProjectRoot 'languages/en-US.json') `
        -Raw `
        -Encoding UTF8 |
        ConvertFrom-Json

    $Italian = Get-Content `
        (Join-Path $ProjectRoot 'languages/it-IT.json') `
        -Raw `
        -Encoding UTF8 |
        ConvertFrom-Json

    $EnglishKeys = @($English.PSObject.Properties.Name | Sort-Object)
    $ItalianKeys = @($Italian.PSObject.Properties.Name | Sort-Object)

    if (Compare-Object $EnglishKeys $ItalianKeys) {
        Add-MT4AutotestError 'Language key mismatch between en-US and it-IT.'
    }
}
catch {
    Add-MT4AutotestError $_.Exception.Message
}

try {
    . (Join-Path $ProjectRoot 'app/core/Bootstrap.ps1')

    $CommandsBeforeInitialization = @(
        'Add-Log',
        'Write-Main',
        'Write-Ok',
        'Write-WarnLog',
        'Write-Skip',
        'Write-ErrorLog',
        'Read-IniFile',
        'Get-IniValue',
        'Get-IniBool',
        'Set-ModuleResult',
        'Invoke-LoggedProcess',
        'Invoke-LoggedProcessWithHeartbeat',
        'New-MTModuleResult',
        'Write-MTCoreStatus'
    )

    foreach ($CommandName in $CommandsBeforeInitialization) {
        if (-not (Get-Command $CommandName -ErrorAction SilentlyContinue)) {
            throw "Core command missing before initialization: $CommandName"
        }
    }

    $Context = Initialize-MT4Foundation -ProjectRoot $ProjectRoot

    if (-not $Context.Language) {
        throw 'Language context missing.'
    }

    foreach ($CommandName in $CommandsBeforeInitialization) {
        if (-not (Get-Command $CommandName -ErrorAction SilentlyContinue)) {
            throw "Core command disappeared after initialization: $CommandName"
        }
    }
}
catch {
    Add-MT4AutotestError (
        'Foundation smoke test failed: {0}' -f $_.Exception.Message
    )
}

try {
    $CommonPath = Join-Path $ProjectRoot 'app/modules/00_common.ps1'
    $CommonText = Get-Content -LiteralPath $CommonPath -Raw -Encoding UTF8

    if ($CommonText -match '(?m)^function\s+') {
        throw 'app/modules/00_common.ps1 still contains function implementations.'
    }

    . $CommonPath

    foreach ($CommandName in @(
        'Add-Log',
        'Write-Main',
        'Set-ModuleResult',
        'Invoke-LoggedProcess'
    )) {
        if (-not (Get-Command $CommandName -ErrorAction SilentlyContinue)) {
            throw "Compatibility loader did not expose: $CommandName"
        }
    }
}
catch {
    Add-MT4AutotestError (
        'Compatibility loader smoke test failed: {0}' -f $_.Exception.Message
    )
}


try {
    $English = Get-Content (Join-Path $ProjectRoot 'languages/en-US.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $Italian = Get-Content (Join-Path $ProjectRoot 'languages/it-IT.json') -Raw -Encoding UTF8 | ConvertFrom-Json

    foreach ($Key in @(
        'LANGUAGE_NAME','MODE_AUTOMATIC','MODE_MANUAL',
        'MENU_RUN_AUTOMATIC','MENU_OPEN_CONFIG','MENU_OPEN_LOGS',
        'MENU_SELFTEST','MENU_CHECK_UPDATES','MENU_INFO','MENU_RETURN',
        'MENU_EXIT','MENU_SELECTION','SESSION_LABEL',
        'SESSION_SELECTED_MODULES','SESSION_QUICK_SUMMARY',
        'SESSION_EXECUTED','SESSION_NOT_EXECUTED',
        'TABLE_MODULE','TABLE_STATUS','TABLE_DURATION','TABLE_DETAIL',
        'MODULE_CONNECTIVITY','MODULE_INVENTORY','MODULE_WINGET'
    )) {
        if (-not $English.PSObject.Properties[$Key]) { throw "Missing en-US shell key: $Key" }
        if (-not $Italian.PSObject.Properties[$Key]) { throw "Missing it-IT shell key: $Key" }
    }

    $MainPath = Join-Path $ProjectRoot 'app/MaintenanceToolkit.ps1'
    Test-MT4PowerShellSyntax $MainPath

    foreach ($RuntimeScript in @($MainPath) + @(
        Get-ChildItem (Join-Path $ProjectRoot 'app/core') -Filter *.ps1 -File |
            Select-Object -ExpandProperty FullName
    )) {
        $Bytes = [System.IO.File]::ReadAllBytes($RuntimeScript)
        if ($Bytes.Length -lt 3 -or $Bytes[0] -ne 0xEF -or $Bytes[1] -ne 0xBB -or $Bytes[2] -ne 0xBF) {
            throw "UTF-8 BOM required for Windows PowerShell 5.1: $RuntimeScript"
        }
    }
}
catch {
    Add-MT4AutotestError ('Bilingual shell validation failed: {0}' -f $_.Exception.Message)
}

try {
    $OverrideSettings = Import-MTSettings -ProjectRoot $ProjectRoot
    $OverrideSettings.Language = 'en-US'

    $EnglishContext = Initialize-MT4Foundation `
        -ProjectRoot $ProjectRoot `
        -Settings $OverrideSettings

    if ([string]$EnglishContext.LanguageResolution.Language -ne 'en-US') {
        throw (
            'Explicit language override failed. Expected en-US, got {0}.' -f
            $EnglishContext.LanguageResolution.Language
        )
    }

    if ([string]$EnglishContext.Language.LANGUAGE_NAME -ne 'English') {
        throw 'Explicit en-US override loaded the wrong language dictionary.'
    }

    $OverrideSettings = Import-MTSettings -ProjectRoot $ProjectRoot
    $OverrideSettings.Language = 'it-IT'

    $ItalianContext = Initialize-MT4Foundation `
        -ProjectRoot $ProjectRoot `
        -Settings $OverrideSettings

    if ([string]$ItalianContext.LanguageResolution.Language -ne 'it-IT') {
        throw (
            'Explicit language override failed. Expected it-IT, got {0}.' -f
            $ItalianContext.LanguageResolution.Language
        )
    }

    if ([string]$ItalianContext.Language.LANGUAGE_NAME -ne 'Italiano') {
        throw 'Explicit it-IT override loaded the wrong language dictionary.'
    }
}
catch {
    Add-MT4AutotestError (
        'Language override validation failed: {0}' -f $_.Exception.Message
    )
}

try {
    $ExpectedProjectRoot = $ProjectRoot
    . (Join-Path $ProjectRoot 'app/modules/00_common.ps1')

    if ($ProjectRoot -ne $ExpectedProjectRoot) {
        throw (
            'Compatibility loader changed caller ProjectRoot from {0} to {1}.' -f
            $ExpectedProjectRoot,
            $ProjectRoot
        )
    }

    if (
        -not (Test-Path -LiteralPath (
            Join-Path $ProjectRoot 'app/core/Localization.ps1'
        ))
    ) {
        throw 'Compatibility loader resolved the wrong repository root.'
    }
}
catch {
    Add-MT4AutotestError (
        'Compatibility root isolation failed: {0}' -f $_.Exception.Message
    )
}

try {
    $PreviousLanguage = $env:MT_LANGUAGE

    try {
        $env:MT_LANGUAGE = 'en-US'
        . (Join-Path $ProjectRoot 'app/modules/00_common.ps1')

        $EnglishConnectivity = Get-MTRuntimeText `
            'CONNECTIVITY_GATEWAY_OK' `
            @('192.0.2.1')

        if ($EnglishConnectivity -ne 'Gateway reachable: 192.0.2.1') {
            throw "Runtime en-US module localization failed: $EnglishConnectivity"
        }

        $env:MT_LANGUAGE = 'it-IT'
        Initialize-MTRuntimeLocalization `
            -ProjectRoot $ProjectRoot `
            -Language $env:MT_LANGUAGE |
            Out-Null

        $ItalianConnectivity = Get-MTRuntimeText `
            'CONNECTIVITY_GATEWAY_OK' `
            @('192.0.2.1')

        if ($ItalianConnectivity -ne 'Gateway raggiungibile: 192.0.2.1') {
            throw "Runtime it-IT module localization failed: $ItalianConnectivity"
        }
    }
    finally {
        $env:MT_LANGUAGE = $PreviousLanguage
    }

    foreach ($RelativeModule in @(
        'app/modules/01_connectivity.ps1',
        'app/modules/05_winget.ps1'
    )) {
        $MigratedModule = Join-Path $ProjectRoot $RelativeModule
        Test-MT4PowerShellSyntax $MigratedModule

        $ModuleText = Get-Content `
            -LiteralPath $MigratedModule `
            -Raw `
            -Encoding UTF8

        foreach ($Pattern in @(
            '(?m)\bWrite-Main\s+"[^"]+',
            '(?m)\bWrite-Ok\s+"[^"]+',
            '(?m)\bWrite-WarnLog\s+"[^"]+',
            '(?m)\bWrite-ErrorLog\s+"[^"]+',
            '(?m)\bthrow\s+"[^"]+',
            '(?m)-Label\s+"[^"]+'
        )) {
            if ($ModuleText -match $Pattern) {
                throw (
                    'Migrated module contains a hardcoded user-facing string: {0}' -f
                    $RelativeModule
                )
            }
        }
    }
}
catch {
    Add-MT4AutotestError (
        'Migrated module localization validation failed: {0}' -f
        $_.Exception.Message
    )
}

try {
    $PreviousLanguage = $env:MT_LANGUAGE

    try {
        $env:MT_LANGUAGE = 'en-US'
        Initialize-MTRuntimeLocalization `
            -ProjectRoot $ProjectRoot `
            -Language $env:MT_LANGUAGE |
            Out-Null

        $Cases = @(
            @('PROCESS_LONG_START', @('Winget pass 1'), 'Winget pass 1 may take several minutes. Do not close the window.'),
            @('PROCESS_LONG_RUNNING', @('Winget pass 1','00:01:00'), 'Winget pass 1 is still running. Elapsed time: 00:01:00'),
            @('PROCESS_COMPLETED_DURATION', @('Winget pass 1','00:01:02',0), 'Winget pass 1 completed in 00:01:02. Exit code 0.'),
            @('PROCESS_FAILED_DURATION', @('Winget pass 1','00:01:02',1), 'Winget pass 1 failed after 00:01:02. Exit code 1.'),
            @('PROCESS_COMPLETED', @('Winget source update',0), 'Winget source update completed. Exit code 0.'),
            @('PROCESS_FAILED', @('Winget source update',1), 'Winget source update failed. Exit code 1.')
        )

        foreach ($Case in $Cases) {
            $Actual = Get-MTRuntimeText $Case[0] $Case[1]
            if ($Actual -ne $Case[2]) {
                throw "ProcessRunner en-US localization failed for $($Case[0]): $Actual"
            }
        }

        $env:MT_LANGUAGE = 'it-IT'
        Initialize-MTRuntimeLocalization `
            -ProjectRoot $ProjectRoot `
            -Language $env:MT_LANGUAGE |
            Out-Null

        if (
            (Get-MTRuntimeText 'PROCESS_LONG_START' @('Winget passaggio 1')) -ne
            'Winget passaggio 1 può richiedere diversi minuti. Non chiudere la finestra.'
        ) {
            throw 'ProcessRunner it-IT start localization failed.'
        }
    }
    finally {
        $env:MT_LANGUAGE = $PreviousLanguage
    }

    $ProcessRunnerPath = Join-Path $ProjectRoot 'app/core/ProcessRunner.ps1'
    $ProcessRunnerText = Get-Content -LiteralPath $ProcessRunnerPath -Raw -Encoding UTF8

    foreach ($ForbiddenText in @(
        'può richiedere diversi minuti',
        'ancora in esecuzione. Tempo trascorso',
        '$Label completato',
        '$Label fallito'
    )) {
        if ($ProcessRunnerText.Contains($ForbiddenText)) {
            throw "Hardcoded ProcessRunner UI text remains: $ForbiddenText"
        }
    }
}
catch {
    Add-MT4AutotestError (
        'ProcessRunner localization validation failed: {0}' -f
        $_.Exception.Message
    )
}

try {
    $ExpectedRootFiles = @(
        'Avvia_Manutenzione.bat',
        'README.md',
        'CONTRIBUTING.md',
        'LICENSE',
        '.gitignore'
    )

    foreach ($RootFile in $ExpectedRootFiles) {
        if (-not (Test-Path -LiteralPath (Join-Path $ProjectRoot $RootFile) -PathType Leaf)) {
            throw "Expected repository root file missing: $RootFile"
        }
    }

    foreach ($ForbiddenRootFile in @(
        'MaintenanceToolkit.ps1',
        'MaintenanceToolkit.ini',
        'ABOUT.txt',
        'CHANGELOG.md'
    )) {
        if (Test-Path -LiteralPath (Join-Path $ProjectRoot $ForbiddenRootFile)) {
            throw "Root cleanup regression: $ForbiddenRootFile"
        }
    }

    foreach ($RequiredRuntimePath in @(
        'app/MaintenanceToolkit.ps1',
        'app/modules/00_common.ps1',
        'config/MaintenanceToolkit.ini',
        'docs/ABOUT.txt',
        'docs/CHANGELOG.md'
    )) {
        if (-not (Test-Path -LiteralPath (Join-Path $ProjectRoot $RequiredRuntimePath))) {
            throw "Structured path missing: $RequiredRuntimePath"
        }
    }
}
catch {
    Add-MT4AutotestError (
        'Repository/runtime structure validation failed: {0}' -f
        $_.Exception.Message
    )
}

try {
    $LegacySmoke = Join-Path `
        $ProjectRoot `
        'app/tools/Test-MT4LegacyCompatibility.ps1'

    $LegacyProcess = Start-Process `
        -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" `
        -ArgumentList @(
            '-NoProfile',
            '-ExecutionPolicy', 'Bypass',
            '-File', ('"{0}"' -f $LegacySmoke),
            '-ProjectRoot', ('"{0}"' -f $ProjectRoot)
        ) `
        -Wait `
        -PassThru `
        -NoNewWindow

    if ($LegacyProcess.ExitCode -ne 0) {
        throw (
            'Legacy compatibility smoke test failed with exit code {0}.' -f
            $LegacyProcess.ExitCode
        )
    }
}
catch {
    Add-MT4AutotestError (
        'Legacy compatibility smoke test failed: {0}' -f $_.Exception.Message
    )
}

Write-Host (
    'MT4 Foundation AUTOTEST: {0} error(s), {1} warning(s)' -f
    $Errors.Count,
    $Warnings.Count
)

$Errors |
    ForEach-Object {
        Write-Host ('[ERROR] ' + $_) -ForegroundColor Red
    }

$Warnings |
    ForEach-Object {
        Write-Host ('[WARN ] ' + $_) -ForegroundColor Yellow
    }

if ($Errors.Count -gt 0) {
    exit 1
}

exit 0
