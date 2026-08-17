# Maintenance Toolkit - Power management helpers
#
# Keeps Windows awake while Maintenance Toolkit is running without changing
# the active power plan and without forcing the display to remain on.

$script:MTExecutionStateTypeName = 'MaintenanceToolkit.Native.PowerManagement'

if (-not ($script:MTExecutionStateTypeName -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

namespace MaintenanceToolkit.Native
{
    public static class PowerManagement
    {
        [Flags]
        public enum ExecutionState : uint
        {
            ES_SYSTEM_REQUIRED = 0x00000001,
            ES_CONTINUOUS      = 0x80000000
        }

        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern ExecutionState SetThreadExecutionState(
            ExecutionState esFlags
        );
    }
}
'@
}

function Enable-MTSystemAwake {
    [CmdletBinding()]
    param()

    $RequiredState = (
        [MaintenanceToolkit.Native.PowerManagement+ExecutionState]::ES_CONTINUOUS -bor
        [MaintenanceToolkit.Native.PowerManagement+ExecutionState]::ES_SYSTEM_REQUIRED
    )

    $Result = [MaintenanceToolkit.Native.PowerManagement]::SetThreadExecutionState(
        $RequiredState
    )

    return ([uint32]$Result -ne 0)
}

function Disable-MTSystemAwake {
    [CmdletBinding()]
    param()

    $Result = [MaintenanceToolkit.Native.PowerManagement]::SetThreadExecutionState(
        [MaintenanceToolkit.Native.PowerManagement+ExecutionState]::ES_CONTINUOUS
    )

    return ([uint32]$Result -ne 0)
}
