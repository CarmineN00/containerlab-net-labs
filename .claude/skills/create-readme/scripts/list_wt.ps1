# Elenca gli handle delle finestre top-level di Windows Terminal.
Get-Process WindowsTerminal -ErrorAction SilentlyContinue | ForEach-Object { $_.Refresh() }
Add-Type @"
using System; using System.Text; using System.Runtime.InteropServices; using System.Collections.Generic;
public class E {
  public delegate bool P(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(P p, IntPtr l);
  [DllImport("user32.dll")] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  public static List<string> L() { var o = new List<string>();
    EnumWindows((h, l) => { var c = new StringBuilder(256); GetClassName(h, c, 256);
      if (c.ToString() == "CASCADIA_HOSTING_WINDOW_CLASS" && IsWindowVisible(h)) {
        var t = new StringBuilder(256); GetWindowText(h, t, 256); o.Add(h.ToInt64() + "`t" + t); }
      return true; }, IntPtr.Zero); return o; }
}
"@
[E]::L()
