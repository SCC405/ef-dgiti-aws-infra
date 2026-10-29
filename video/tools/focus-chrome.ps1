# Trae al frente y maximiza la ventana de Chrome cuyo título contiene $Match.
param([string] $Match = 'Google Chrome')

Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class Win {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
    [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, int flags, IntPtr extra);
}
'@

$win = Get-Process chrome -ErrorAction SilentlyContinue |
    Where-Object { $_.MainWindowHandle -ne 0 -and $_.MainWindowTitle -like "*$Match*" } |
    Select-Object -First 1
if (-not $win) { Write-Host "No hay ventana de Chrome con '$Match'"; exit 1 }

# Pulsar y soltar ALT permite a un proceso en segundo plano tomar el foco.
[Win]::keybd_event(0x12, 0, 0, [IntPtr]::Zero)
[Win]::keybd_event(0x12, 0, 2, [IntPtr]::Zero)
[Win]::ShowWindow($win.MainWindowHandle, 3) | Out-Null   # SW_MAXIMIZE
[Win]::SetForegroundWindow($win.MainWindowHandle) | Out-Null
Write-Host "Al frente: $($win.MainWindowTitle)"
