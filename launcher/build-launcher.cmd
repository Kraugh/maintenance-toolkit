@echo off
setlocal

set "ROOT=%~dp0.."
set "LAUNCHER=%~dp0"
set "BUILD=%LAUNCHER%build"
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"

if not exist "%BUILD%" mkdir "%BUILD%"

for /f "usebackq tokens=*" %%I in (`"%VSWHERE%" -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do (
    set "VSROOT=%%I"
)

if not defined VSROOT (
    echo ERROR: MSVC x64/x86 build tools not found.
    exit /b 1
)

call "%VSROOT%\VC\Auxiliary\Build\vcvars64.bat"
if errorlevel 1 exit /b %errorlevel%

rc /nologo ^
    /fo "%BUILD%\MaintenanceToolkit.res" ^
    "%LAUNCHER%MaintenanceToolkit.rc"

if errorlevel 1 exit /b %errorlevel%

cl /nologo /std:c++17 /O2 /EHsc /DUNICODE /D_UNICODE ^
    /Fo"%BUILD%\MaintenanceToolkitLauncher.obj" ^
    "%LAUNCHER%MaintenanceToolkitLauncher.cpp" ^
    "%BUILD%\MaintenanceToolkit.res" ^
    /Fe:"%ROOT%\MaintenanceToolkit.exe" ^
    /link ^
    /MANIFEST:EMBED ^
    /MANIFESTUAC:NO ^
    /MANIFESTINPUT:"%LAUNCHER%app.manifest" ^
    user32.lib

if errorlevel 1 exit /b %errorlevel%

echo.
echo MaintenanceToolkit.exe build completed successfully.
exit /b 0
