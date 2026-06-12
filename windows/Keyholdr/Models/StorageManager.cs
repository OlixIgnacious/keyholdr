using System;
using System.Collections.Generic;
using System.IO;
using System.Text.Json;

namespace Keyholdr.Models
{
    public static class StorageManager
    {
        private static readonly string AppDataFolder = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
            "Keyholdr"
        );

        private static readonly string FilePath = Path.Combine(AppDataFolder, "keys.json");

        public static List<KeyItem> LoadKeys()
        {
            try
            {
                if (!File.Exists(FilePath))
                {
                    return new List<KeyItem>();
                }

                string json = File.ReadAllText(FilePath);
                var items = JsonSerializer.Deserialize<List<KeyItem>>(json);
                return items ?? new List<KeyItem>();
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Error loading metadata keys: {ex.Message}");
                return new List<KeyItem>();
            }
        }

        public static void SaveKeys(List<KeyItem> keys)
        {
            try
            {
                if (!Directory.Exists(AppDataFolder))
                {
                    Directory.CreateDirectory(AppDataFolder);
                }

                var options = new JsonSerializerOptions { WriteIndented = true };
                string json = JsonSerializer.Serialize(keys, options);
                File.WriteAllText(FilePath, json);
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Error saving metadata keys: {ex.Message}");
            }
        }
    }
}
