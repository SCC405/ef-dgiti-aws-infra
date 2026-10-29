# Clic real del mouse en coordenadas de pantalla (para elementos fuera de la página).
param([int] $X, [int] $Y)

Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class Mouse {
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern void mouse_event(int flags, int dx, int dy, int data, IntPtr extra);
}
'@

[Mouse]::SetCursorPos($X, $Y) | Out-Null
Start-Sleep -Milliseconds 100
[Mouse]::mouse_event(0x02, 0, 0, 0, [IntPtr]::Zero)   # izquierdo abajo
[Mouse]::mouse_event(0x04, 0, 0, 0, [IntPtr]::Zero)   # izquierdo arriba
