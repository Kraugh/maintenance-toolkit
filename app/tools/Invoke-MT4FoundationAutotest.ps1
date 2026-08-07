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
    'app/core/Profiler.ps1',
    'app/core/Privileges.ps1',
    'app/modules/00_common.ps1',
    'app/modules/network/NetworkFoundation.ps1',
    'app/modules/network/SpeedTest.ps1',
    'app/modules/network/NetworkDiagnostics.ps1',
    'app/modules/network/NetworkReports.ps1',
    'config/network.json',
    'app/modules/network/TopologyEngine.ps1',
    'app/modules/network/RoutingAnalyzer.ps1',
    'app/modules/network/RulesEngine.ps1',
    'rules/network.json',
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
    . (Join-Path $ProjectRoot 'app/modules/network/NetworkFoundation.ps1')

    $NetworkFoundation = Import-MTNetworkDiagnosticsFoundation `
        -ProjectRoot $ProjectRoot

    if (-not $NetworkFoundation.Loaded) {
        throw 'Network Diagnostics foundation did not report Loaded=true.'
    }

    if ([string]$NetworkFoundation.Baseline -ne 'NDP 0.0.19-RC') {
        throw 'Network Diagnostics baseline identity mismatch.'
    }

    foreach ($PersistentCommandName in @(
        'Get-NDRoutingAnalysis',
        'Get-NDTopology',
        'Export-NDTopology',
        'Invoke-NDRules'
    )) {
        if (-not (Get-Command $PersistentCommandName -ErrorAction SilentlyContinue)) {
            throw (
                'Network Diagnostics command did not survive loader return: {0}' -f
                $PersistentCommandName
            )
        }
    }

    foreach ($CommandName in @(
        'Get-NDRoutingAnalysis',
        'Get-NDTopology',
        'Export-NDTopology',
        'Invoke-NDRules',
        'Start-MTProfiler',
        'Start-MTProfilerStep',
        'Stop-MTProfilerStep',
        'Stop-MTProfiler',
        'Test-MTAdministrator',
        'Get-MTPrivilegeState'
    )) {
        if (-not (Get-Command $CommandName -ErrorAction SilentlyContinue)) {
            throw "MT4/NDP foundation command missing: $CommandName"
        }
    }

    $NetworkRulesPath = Join-Path $ProjectRoot 'rules/network.json'
    $NetworkRules = Get-Content `
        -LiteralPath $NetworkRulesPath `
        -Raw `
        -Encoding UTF8 |
        ConvertFrom-Json

    if (@($NetworkRules.Rules).Count -ne 8) {
        throw (
            'Expected 8 baseline NDP rules, found {0}.' -f
            @($NetworkRules.Rules).Count
        )
    }

    foreach ($ExpectedRule in @(
        'NET001','NET002','VPN001','VPN002',
        'TOP001','TOP002','VPN003','VPN004'
    )) {
        if (-not (@($NetworkRules.Rules.Id) -contains $ExpectedRule)) {
            throw "Baseline NDP rule missing: $ExpectedRule"
        }
    }
}
catch {
    Add-MT4AutotestError (
        'Network Diagnostics foundation validation failed: {0}' -f
        $_.Exception.Message
    )
}

try {
    . (Join-Path $ProjectRoot 'app/modules/network/NetworkDiagnostics.ps1')

    foreach ($CommandName in @(
        'Invoke-MTNetworkQuickDiagnosis',
        'Get-MTNetworkRoutingModeText',
        'Write-MTNetworkStatus'
    )) {
        if (-not (Get-Command $CommandName -ErrorAction SilentlyContinue)) {
            throw "Native MT Network Diagnostics command missing: $CommandName"
        }
    }

    $NetworkActionPath = Join-Path `
        $ProjectRoot `
        'app/modules/network/NetworkDiagnostics.ps1'

    Test-MT4PowerShellSyntax $NetworkActionPath

    $NetworkActionText = Get-Content `
        -LiteralPath $NetworkActionPath `
        -Raw `
        -Encoding UTF8

    foreach ($ForbiddenPattern in @(
        'Start-Process',
        'powershell.exe',
        'pwsh.exe',
        'cmd.exe',
        'RunAs',
        'NetworkDiagnostics.cmd',
        'app\\Start.ps1'
    )) {
        if ($NetworkActionText -match [regex]::Escape($ForbiddenPattern)) {
            throw (
                'Native Network Diagnostics action contains forbidden nested execution/elevation token: {0}' -f
                $ForbiddenPattern
            )
        }
    }

    $NetworkSettings = Get-Content `
        -LiteralPath (Join-Path $ProjectRoot 'config/network.json') `
        -Raw `
        -Encoding UTF8 |
        ConvertFrom-Json

    if (-not $NetworkSettings.Topology.Enabled) {
        throw 'Network Diagnostics topology engine is disabled in config/network.json.'
    }

    if (-not $NetworkSettings.Routing.Enabled) {
        throw 'Network Diagnostics routing engine is disabled in config/network.json.'
    }
}
catch {
    Add-MT4AutotestError (
        'Native Network Diagnostics action validation failed: {0}' -f
        $_.Exception.Message
    )
}

try {
    . (Join-Path $ProjectRoot 'app/modules/network/NetworkDiagnostics.ps1')

    $FakeVirtualAdapter = [pscustomobject]@{
        InterfaceIndex = 7
        Name = 'Ethernet'
        Description = 'Microsoft Hyper-V Network Adapter'
        IsVirtual = $true
    }

    $FakeTopology = [pscustomobject]@{
        EffectivePath = [pscustomobject]@{
            LogicalAdapter = $FakeVirtualAdapter
            PhysicalBackend = $FakeVirtualAdapter
            PhysicalBackendCandidates = @()
            PhysicalBackendSource = $null
        }
    }

    $PreviousLanguage = $env:MT_LANGUAGE
    try {
        $env:MT_LANGUAGE = 'en-US'
        Initialize-MTRuntimeLocalization `
            -ProjectRoot $ProjectRoot `
            -Language $env:MT_LANGUAGE |
            Out-Null

        $Presentation = Get-MTNetworkPhysicalBackendPresentation `
            -Topology $FakeTopology `
            -LanguageData $script:MTRuntimeLanguageData

        if ($Presentation.State -ne 'GuestVirtualOnly') {
            throw (
                'Hyper-V guest backend presentation regression: state={0}' -f
                $Presentation.State
            )
        }

        if ($Presentation.Level -ne 'WARN') {
            throw (
                'Hyper-V guest backend presentation should be WARN, got {0}' -f
                $Presentation.Level
            )
        }
    }
    finally {
        $env:MT_LANGUAGE = $PreviousLanguage
    }
}
catch {
    Add-MT4AutotestError (
        'Hyper-V guest backend presentation validation failed: {0}' -f
        $_.Exception.Message
    )
}

try {
    . (Join-Path $ProjectRoot 'app/modules/network/NetworkReports.ps1')

    foreach ($CommandName in @(
        'Invoke-MTNetworkTechnicalReport',
        'New-MTNetworkReportHeader',
        'Get-MTNetworkArtifactPrefix',
        'ConvertTo-MTAsciiSafeToken'
    )) {
        if (-not (Get-Command $CommandName -ErrorAction SilentlyContinue)) {
            throw "Native MT Network Report command missing: $CommandName"
        }
    }

    $PreviousLanguage = $env:MT_LANGUAGE

    try {
        $env:MT_LANGUAGE = 'en-US'
        Initialize-MTRuntimeLocalization `
            -ProjectRoot $ProjectRoot `
            -Language $env:MT_LANGUAGE |
            Out-Null

        $Header = @(
            New-MTNetworkReportHeader `
                -LanguageData $script:MTRuntimeLanguageData `
                -Version '4.0.0-test' `
                -RunId '20260807-130000' `
                -ComputerName 'TEST-PC' `
                -Timestamp ([datetime]'2026-08-07T13:00:00') `
                -OptionCode 'N2' `
                -ReportType 'Technical' `
                -SpeedTestIncluded $false
        )

        if ($Header.Count -ne 8) {
            throw "Expected 8 report identity lines, found $($Header.Count)."
        }

        foreach ($RequiredIdentity in @(
            'Maintenance Toolkit',
            'Menu option',
            'Report type',
            'SpeedTest',
            'Scope',
            'RunId',
            'Computer',
            'Timestamp'
        )) {
            if (-not ($Header -match [regex]::Escape($RequiredIdentity))) {
                throw "Report identity field missing: $RequiredIdentity"
            }
        }

        $Prefix = Get-MTNetworkArtifactPrefix `
            -ComputerName 'PC CON SPAZI/ACCENTI' `
            -RunId '20260807-130000' `
            -ReportType 'Technical' `
            -OptionCode 'N2'

        if ($Prefix -notmatch '^[A-Za-z0-9._-]+$') {
            throw "Artifact prefix is not ASCII-safe: $Prefix"
        }
    }
    finally {
        $env:MT_LANGUAGE = $PreviousLanguage
    }

    $ReportScriptPath = Join-Path `
        $ProjectRoot `
        'app/modules/network/NetworkReports.ps1'

    Test-MT4PowerShellSyntax $ReportScriptPath

    $ReportScriptText = Get-Content `
        -LiteralPath $ReportScriptPath `
        -Raw `
        -Encoding UTF8

    foreach ($ForbiddenPattern in @(
        'Start-Process',
        'powershell.exe',
        'pwsh.exe',
        'cmd.exe',
        'RunAs',
        'NetworkDiagnostics.cmd',
        'app\\Start.ps1'
    )) {
        if ($ReportScriptText -match [regex]::Escape($ForbiddenPattern)) {
            throw (
                'Native Network Report contains forbidden nested execution/elevation token: {0}' -f
                $ForbiddenPattern
            )
        }
    }
}
catch {
    Add-MT4AutotestError (
        'Native Network Technical Report validation failed: {0}' -f
        $_.Exception.Message
    )
}

try {
    $ReportScriptPath = Join-Path `
        $ProjectRoot `
        'app/modules/network/NetworkReports.ps1'

    $ReportScriptText = Get-Content `
        -LiteralPath $ReportScriptPath `
        -Raw `
        -Encoding UTF8

    # Windows PowerShell 5.1 does not accept an unparenthesized command
    # invocation directly as a .NET method argument, e.g.:
    #   $List.Add(Get-MTText ...)
    # Keep a regression guard for the exact pattern that broke dev.14.
    foreach ($MethodCall in @(
        '\.Add\(\s*Get-MTText\b',
        '\.Add\(\s*Get-MTRuntimeText\b'
    )) {
        if ($ReportScriptText -match $MethodCall) {
            throw (
                'Unparenthesized command invocation found inside .Add(): {0}' -f
                $MethodCall
            )
        }
    }
}
catch {
    Add-MT4AutotestError (
        'Network Report PowerShell 5.1 parser compatibility validation failed: {0}' -f
        $_.Exception.Message
    )
}

try {
    . (Join-Path $ProjectRoot 'app/modules/network/NetworkReports.ps1')

    $TestLines = New-Object System.Collections.Generic.List[string]

    Add-MTNetworkReportSection `
        -Lines $TestLines `
        -Title 'Test section'

    Add-MTNetworkReportKeyValue `
        -Lines $TestLines `
        -Key 'Empty value' `
        -Value ''

    if ($TestLines.Count -lt 4) {
        throw (
            'Report helper mutable-buffer test produced too few lines: {0}' -f
            $TestLines.Count
        )
    }

    if ($TestLines[0] -ne '') {
        throw 'Report section helper did not preserve the blank separator line.'
    }
}
catch {
    Add-MT4AutotestError (
        'Network Report mutable-buffer validation failed: {0}' -f
        $_.Exception.Message
    )
}

try {
    $FormatSamples = @(
        ("{0}: {1}" -f "ERROR", "sample"),
        ("[{0}] {1} | {2} | {3} | {4} | {5}" -f 1, "Ethernet", "Up", "1 Gbps", "virtual", "Adapter"),
        ("{0} -> {1} | if={2} ({3}) | metric={4}" -f "0.0.0.0/0", "10.0.1.254", 5, "Ethernet", 25),
        ("[{0}] {1} | {2}" -f 7, "VPN", "Adapter"),
        ("[{0}] {1} {2}: {3}" -f "Info", "TOP002", "Virtual route", "Sample"),
        ("{0,-12} {1,-7} {2,10:N2} ms {3}" -f "Topology", "OK", 12.34, "")
    )

    if ($FormatSamples.Count -ne 6) {
        throw "Expected 6 network report format samples, found $($FormatSamples.Count)."
    }

    foreach ($Sample in $FormatSamples) {
        if ([string]::IsNullOrWhiteSpace([string]$Sample)) {
            throw 'A network report format sample produced an empty string.'
        }
    }

    $ReportScriptPath = Join-Path `
        $ProjectRoot `
        'app/modules/network/NetworkReports.ps1'

    $ReportScriptText = Get-Content `
        -LiteralPath $ReportScriptPath `
        -Raw `
        -Encoding UTF8

    foreach ($Pattern in @(
        '"\{0\}: \{1\}" -f\s*\r?\n',
        '"\[\{0\}\] \{1\} \| \{2\} \| \{3\} \| \{4\} \| \{5\}" -f\s*\r?\n',
        '"\{0\} -> \{1\} \| if=\{2\} \(\{3\}\) \| metric=\{4\}" -f\s*\r?\n',
        '"\[\{0\}\] \{1\} \| \{2\}" -f\s*\r?\n',
        '"\[\{0\}\] \{1\} \{2\}: \{3\}" -f\s*\r?\n',
        '"\{0,-12\} \{1,-7\} \{2,10:N2\} ms \{3\}" -f\s*\r?\n'
    )) {
        if ($ReportScriptText -match $Pattern) {
            throw "Unsafe multiline format operator remains: $Pattern"
        }
    }
}
catch {
    Add-MT4AutotestError (
        'Network Report format-operator validation failed: {0}' -f
        $_.Exception.Message
    )
}

try {
    . (Join-Path $ProjectRoot 'app/modules/network/NetworkReports.ps1')

    $FormatterCases = @(
        [pscustomobject]@{
            Template = '{0}'
            Arguments = @('A')
            Expected = 'A'
        },
        [pscustomobject]@{
            Template = '{0} {1}'
            Arguments = @('A','B')
            Expected = 'A B'
        },
        [pscustomobject]@{
            Template = '[{0}] {1} | {2} | {3} | {4} | {5}'
            Arguments = @(1,'Ethernet','Up','1 Gbps','virtual','Adapter')
            Expected = '[1] Ethernet | Up | 1 Gbps | virtual | Adapter'
        },
        [pscustomobject]@{
            Template = '{0} -> {1} | if={2} ({3}) | metric={4}'
            Arguments = @('0.0.0.0/0','10.0.1.254',5,'Ethernet',25)
            Expected = '0.0.0.0/0 -> 10.0.1.254 | if=5 (Ethernet) | metric=25'
        }
    )

    foreach ($Case in $FormatterCases) {
        $Actual = Format-MTNetworkReportText `
            -Template $Case.Template `
            -Arguments @($Case.Arguments)

        if ($Actual -ne $Case.Expected) {
            throw (
                "Safe report formatter mismatch. Expected='{0}' Actual='{1}'" -f @(
                    $Case.Expected,
                    $Actual
                )
            )
        }
    }

    $FailureWasExplicit = $false
    try {
        $null = Format-MTNetworkReportText `
            -Template '{0} {1}' `
            -Arguments @('only-one')
    }
    catch {
        $FailureWasExplicit = (
            $_.Exception.Message -match 'Report format failure'
        )
    }

    if (-not $FailureWasExplicit) {
        throw 'Safe report formatter did not expose an intentional argument mismatch.'
    }

    $ReportScriptPath = Join-Path `
        $ProjectRoot `
        'app/modules/network/NetworkReports.ps1'

    $ReportScriptText = Get-Content `
        -LiteralPath $ReportScriptPath `
        -Raw `
        -Encoding UTF8

    # Outside the formatter's own diagnostic catch, report composition should
    # no longer use PowerShell's -f operator.
    $CompositionText = $ReportScriptText -replace `
        '(?s)function Format-MTNetworkReportText \{.*?\n\}', `
        ''

    if ($CompositionText -match '\s-f\s') {
        throw 'PowerShell -f operator remains in Network Report composition.'
    }
}
catch {
    Add-MT4AutotestError (
        'Network Report safe formatter validation failed: {0}' -f
        $_.Exception.Message
    )
}

try {
    $SettingsPath = Join-Path $ProjectRoot 'config/settings.json'
    $RuntimeSettings = Get-Content `
        -LiteralPath $SettingsPath `
        -Raw `
        -Encoding UTF8 |
        ConvertFrom-Json

    $ConfiguredReports = [string]$RuntimeSettings.Paths.Reports

    if ($ConfiguredReports -ne 'reports') {
        throw (
            "Expected settings Paths.Reports='reports', found '{0}'." -f
            $ConfiguredReports
        )
    }

    $ReportScriptPath = Join-Path `
        $ProjectRoot `
        'app/modules/network/NetworkReports.ps1'

    $ReportScriptText = Get-Content `
        -LiteralPath $ReportScriptPath `
        -Raw `
        -Encoding UTF8

    if ($ReportScriptText -notmatch '\$RuntimeSettings\.Paths\.Reports') {
        throw 'Network Report does not consume settings Paths.Reports.'
    }

    if ($ReportScriptText -match '\$RuntimeSettings\.ReportDirectory') {
        throw 'Legacy/incorrect ReportDirectory setting lookup remains.'
    }
}
catch {
    Add-MT4AutotestError (
        'Network Report directory configuration validation failed: {0}' -f
        $_.Exception.Message
    )
}

try {
    . (Join-Path $ProjectRoot 'app/modules/network/SpeedTest.ps1')

    foreach ($CommandName in @(
        'Get-MTNetworkSpeedTestExecutable',
        'ConvertFrom-MTNetworkSpeedTestJson',
        'Invoke-MTNetworkSpeedTest',
        'Show-MTNetworkSpeedTestResult'
    )) {
        if (-not (Get-Command $CommandName -ErrorAction SilentlyContinue)) {
            throw "Native MT SpeedTest command missing: $CommandName"
        }
    }

    $SampleJson = @'
{
  "ping": { "latency": 12.3, "jitter": 1.2 },
  "download": { "bandwidth": 12500000 },
  "upload": { "bandwidth": 6250000 },
  "packetLoss": 0,
  "server": {
    "name": "Test ISP",
    "host": "speed.example.test",
    "location": "Bologna",
    "country": "Italy"
  },
  "interface": { "externalIp": "203.0.113.10" },
  "result": { "url": "https://example.test/result" }
}
'@

    $Parsed = ConvertFrom-MTNetworkSpeedTestJson -JsonText $SampleJson

    if ([double]$Parsed.DownloadMbps -ne 100) {
        throw "SpeedTest download conversion failed: $($Parsed.DownloadMbps)"
    }

    if ([double]$Parsed.UploadMbps -ne 50) {
        throw "SpeedTest upload conversion failed: $($Parsed.UploadMbps)"
    }

    $SpeedScriptPath = Join-Path `
        $ProjectRoot `
        'app/modules/network/SpeedTest.ps1'

    Test-MT4PowerShellSyntax $SpeedScriptPath

    $SpeedScriptText = Get-Content `
        -LiteralPath $SpeedScriptPath `
        -Raw `
        -Encoding UTF8

    foreach ($ForbiddenToken in @(
        'Invoke-WebRequest',
        'Invoke-RestMethod',
        'Start-BitsTransfer',
        'RunAs'
    )) {
        if ($SpeedScriptText -match [regex]::Escape($ForbiddenToken)) {
            throw "SpeedTest service contains forbidden download/elevation token: $ForbiddenToken"
        }
    }

    if ($SpeedScriptText -notmatch 'external\\speedtest\.exe') {
        throw 'SpeedTest service does not search the MT external directory.'
    }

    $ReportScript = Get-Content `
        -LiteralPath (Join-Path $ProjectRoot 'app/modules/network/NetworkReports.ps1') `
        -Raw `
        -Encoding UTF8

    if ($ReportScript -notmatch 'SpeedTestIncluded \(\[bool\]\$SpeedTest\)') {
        throw 'Technical Report does not derive header SpeedTest state from the action.'
    }
}
catch {
    Add-MT4AutotestError (
        'Native optional SpeedTest validation failed: {0}' -f
        $_.Exception.Message
    )
}

try {
    $ReportScriptPath = Join-Path `
        $ProjectRoot `
        'app/modules/network/NetworkReports.ps1'

    $ReportScriptText = Get-Content `
        -LiteralPath $ReportScriptPath `
        -Raw `
        -Encoding UTF8

    foreach ($ForbiddenSpeedTemplate in @(
        '"{0} ms" -f',
        '"{0} Mbps" -f',
        '"{0} %" -f'
    )) {
        if ($ReportScriptText.Contains($ForbiddenSpeedTemplate)) {
            throw (
                'SpeedTest report bypasses the safe formatter: {0}' -f
                $ForbiddenSpeedTemplate
            )
        }
    }
}
catch {
    Add-MT4AutotestError (
        'SpeedTest report formatter integration validation failed: {0}' -f
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
