using System.Runtime.InteropServices;

namespace ChatGPTMonitor;

internal static class WindowsBackdrop
{
    private const int DwmwaUseImmersiveDarkMode = 20;
    private const int DwmwaWindowCornerPreference = 33;
    private const int DwmwaBorderColor = 34;
    private const int DwmwaSystemBackdropType = 38;
    public const int CornerPreferenceForIsland = 1;
    public const int SystemBackdropTypeForIsland = 1;
    public const int BorderColorForIsland = -2;

    public static void Apply(nint windowHandle)
    {
        if (!OperatingSystem.IsWindowsVersionAtLeast(10, 0, 22000)) return;
        TrySet(windowHandle, DwmwaUseImmersiveDarkMode, 1);
        TrySet(windowHandle, DwmwaWindowCornerPreference, CornerPreferenceForIsland);
        TrySet(windowHandle, DwmwaBorderColor, BorderColorForIsland);
        TrySet(windowHandle, DwmwaSystemBackdropType, SystemBackdropTypeForIsland);
    }

    private static void TrySet(nint windowHandle, int attribute, int value)
    {
        try
        {
            _ = DwmSetWindowAttribute(windowHandle, attribute, ref value, sizeof(int));
        }
        catch (DllNotFoundException)
        {
        }
        catch (EntryPointNotFoundException)
        {
        }
    }

    [DllImport("dwmapi.dll")]
    private static extern int DwmSetWindowAttribute(
        nint windowHandle,
        int attribute,
        ref int value,
        int valueSize);
}
