# Imported/generalized from NDP 0.0.19-RC.
function Test-MTAdministrator {
    [CmdletBinding()]
    param()

    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object `
            Security.Principal.WindowsPrincipal($identity)

        return $principal.IsInRole(
            [Security.Principal.WindowsBuiltInRole]::Administrator
        )
    }
    catch {
        return $false
    }
}

function Get-MTPrivilegeState {
    [CmdletBinding()]
    param()

    $isAdministrator = Test-MTAdministrator

    return [pscustomobject]@{
        IsAdministrator = $isAdministrator
        Identity = [Security.Principal.WindowsIdentity]::GetCurrent().Name
        ProcessId = $PID
        PowerShellVersion = $PSVersionTable.PSVersion.ToString()
        HostName = $Host.Name
    }
}
