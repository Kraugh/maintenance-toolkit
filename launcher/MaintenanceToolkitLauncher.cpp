#include <windows.h>
#include <filesystem>
#include <string>
#include <vector>

static std::wstring QuoteArgument(const std::wstring& value)
{
    std::wstring result = L"\"";
    size_t slashes = 0;
    for (wchar_t ch : value) {
        if (ch == L'\\') { ++slashes; continue; }
        result.append(slashes * (ch == L'"' ? 2 : 1), L'\\');
        slashes = 0;
        if (ch == L'"') result += L'\\';
        result += ch;
    }
    result.append(slashes * 2, L'\\');
    return result + L"\"";
}

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

        wchar_t systemDirectory[MAX_PATH]{};
        if (!GetSystemDirectoryW(systemDirectory, MAX_PATH)) return 1;
        std::wstring powershell = std::wstring(systemDirectory) + L"\\WindowsPowerShell\\v1.0\\powershell.exe";
        std::wstring commandLine = QuoteArgument(powershell) +
            L" -NoLogo -NoProfile -ExecutionPolicy Bypass -File " + QuoteArgument(script.wstring());

        for (int i = 1; i < argc; ++i)
        {
            commandLine += L" " + QuoteArgument(argv[i]);
        }

        STARTUPINFOW si{};
        si.cb = sizeof(si);

        PROCESS_INFORMATION pi{};

        std::vector<wchar_t> buffer(commandLine.begin(), commandLine.end());
        buffer.push_back(L'\0');

        BOOL ok = CreateProcessW(
            powershell.c_str(),
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
