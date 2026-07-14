using Microsoft.Win32;

namespace ChatGPTMonitor;

internal static class StartupManager
{
    private const string RegistryPath = @"Software\Microsoft\Windows\CurrentVersion\Run";
    private const string ValueName = "ChatGPTMonitor";

    public static bool IsEnabled
    {
        get
        {
            using var key = Registry.CurrentUser.OpenSubKey(RegistryPath, false);
            return key?.GetValue(ValueName) is string value &&
                string.Equals(Unquote(value), Environment.ProcessPath, StringComparison.OrdinalIgnoreCase);
        }
    }

    public static void SetEnabled(bool enabled)
    {
        using var key = Registry.CurrentUser.CreateSubKey(RegistryPath, true);
        if (enabled)
        {
            var path = Environment.ProcessPath ?? Application.ExecutablePath;
            key.SetValue(ValueName, $"\"{path}\"");
        }
        else
        {
            key.DeleteValue(ValueName, false);
        }
    }

    private static string Unquote(string value) => value.Trim().Trim('"');
}
