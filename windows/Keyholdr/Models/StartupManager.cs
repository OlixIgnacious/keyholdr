using System;
using Microsoft.Win32;

namespace Keyholdr.Models
{
    /// <summary>
    /// Registers Keyholdr in the per-user Run key so it survives reboots.
    /// </summary>
    public static class StartupManager
    {
        private const string RunKeyPath = @"Software\Microsoft\Windows\CurrentVersion\Run";
        private const string AppKeyPath = @"Software\Keyholdr";
        private const string ValueName = "Keyholdr";
        private const string ConfiguredValueName = "AutostartConfigured";

        public static bool IsEnabled
        {
            get
            {
                using var key = Registry.CurrentUser.OpenSubKey(RunKeyPath);
                return key?.GetValue(ValueName) is not null;
            }
        }

        public static void SetEnabled(bool enabled)
        {
            using var key = Registry.CurrentUser.CreateSubKey(RunKeyPath);
            if (enabled)
            {
                var exePath = Environment.ProcessPath;
                if (exePath is null) return;
                key.SetValue(ValueName, $"\"{exePath}\"");
            }
            else
            {
                key.DeleteValue(ValueName, throwOnMissingValue: false);
            }
        }

        /// <summary>
        /// A tray utility should be there after a reboot out of the box:
        /// enable on the first launch, then never override the user's choice
        /// again. On later launches only refresh the registered exe path, in
        /// case the self-contained binary was moved.
        /// </summary>
        public static void EnableOnFirstLaunch()
        {
            using var appKey = Registry.CurrentUser.CreateSubKey(AppKeyPath);
            if (appKey.GetValue(ConfiguredValueName) is null)
            {
                SetEnabled(true);
                appKey.SetValue(ConfiguredValueName, 1);
            }
            else if (IsEnabled)
            {
                SetEnabled(true);
            }
        }
    }
}
