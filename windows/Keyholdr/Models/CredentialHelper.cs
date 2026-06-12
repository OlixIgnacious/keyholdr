using System;
using Windows.Security.Credentials;

namespace Keyholdr.Models
{
    public static class CredentialHelper
    {
        private const string ResourceName = "com.olixstudios.Keyholdr";

        public static bool Save(string secret, Guid id)
        {
            if (string.IsNullOrWhiteSpace(secret)) return false;

            try
            {
                // Delete existing first to avoid duplicate errors
                Delete(id);

                var vault = new PasswordVault();
                var credential = new PasswordCredential(ResourceName, id.ToString(), secret);
                vault.Add(credential);
                return true;
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Failed to save to PasswordVault: {ex.Message}");
                return false;
            }
        }

        public static string? Retrieve(Guid id)
        {
            try
            {
                var vault = new PasswordVault();
                var credential = vault.Retrieve(ResourceName, id.ToString());
                // PasswordVault retrieves credentials, but Password property needs to be fetched
                credential.RetrievePassword();
                return credential.Password;
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Failed to retrieve from PasswordVault: {ex.Message}");
                return null;
            }
        }

        public static bool Delete(Guid id)
        {
            try
            {
                var vault = new PasswordVault();
                var credential = vault.Retrieve(ResourceName, id.ToString());
                vault.Remove(credential);
                return true;
            }
            catch (Exception)
            {
                // If it doesn't exist, count as deleted/clean
                return true;
            }
        }
    }
}
