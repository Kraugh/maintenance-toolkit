#include <windows.h>
#include <filesystem>
#include <string>
#include <vector>

int wmain(int argc, wchar_t* argv[])
{
    try
    {
        std::filesystem::path root = std::filesystem::path(argv[0]).parent_path();
        std::filesystem::path script = root / L"app" / L"MaintenanceToolkit.ps1";

        if (!std::filesystem::exists(script))
        {
            std::wstring message =
                L"Maintenance Toolkit - ERRORE\n\n"
                L"Script principale non trovato:\n" +
                script.wstring();

            MessageBoxW(
                nullptr,
                message.c_str(),
                L"Maintenance Toolkit",
                MB_OK | MB_ICONERROR
            );

            return 2;
        }

        std::wstring commandLine =
            L"powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File \"" +
            script.wstring() +
            L"\"";

        for (int i = 1; i < argc; ++i)
        {
            commandLine += L" \"";
            commandLine += argv[i];
            commandLine += L"\"";
        }

        STARTUPINFOW si{};
        si.cb = sizeof(si);

        PROCESS_INFORMATION pi{};

        std::vector<wchar_t> buffer(commandLine.begin(), commandLine.end());
        buffer.push_back(L'\0');

        BOOL ok = CreateProcessW(
            nullptr,
            buffer.data(),
            nullptr,
            nullptr,
            FALSE,
            0,
            nullptr,
            root.c_str(),
            &si,
            &pi
        );

        if (!ok)
        {
            MessageBoxW(
                nullptr,
                L"Impossibile avviare PowerShell.",
                L"Maintenance Toolkit",
                MB_OK | MB_ICONERROR
            );

            return 1;
        }

        WaitForSingleObject(pi.hProcess, INFINITE);

        DWORD exitCode = 1;
        GetExitCodeProcess(pi.hProcess, &exitCode);

        CloseHandle(pi.hThread);
        CloseHandle(pi.hProcess);

        return static_cast<int>(exitCode);
    }
    catch (...)
    {
        MessageBoxW(
            nullptr,
            L"Errore imprevisto nel launcher.",
            L"Maintenance Toolkit",
            MB_OK | MB_ICONERROR
        );

        return 1;
    }
}
