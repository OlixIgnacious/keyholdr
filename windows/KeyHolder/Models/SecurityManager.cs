using System;
using System.Threading.Tasks;
using Windows.Security.Credentials.UI;

namespace KeyHolder.Models
{
    public class SecurityManager
    {
        private bool _isUnlocked = false;

        public bool IsUnlocked
        {
            get => _isUnlocked;
            set => _isUnlocked = value;
        }

        public async Task<bool> AuthenticateAsync(string reason = "access your secure keys")
        {
            if (_isUnlocked)
            {
                return true;
            }

            try
            {
                // Check if Windows Hello (fingerprint, facial recognition, or PIN) is supported & configured
                var availability = await UserConsentVerifier.CheckAvailabilityAsync();
                if (availability == UserConsentVerifierAvailability.Available)
                {
                    var consentResult = await UserConsentVerifier.RequestVerificationAsync(reason);
                    _isUnlocked = consentResult == UserConsentVerificationResult.Verified;
                    return _isUnlocked;
                }
                else
                {
                    // Windows Hello not configured or supported (similar to macOS VM/CI environment fallback)
                    _isUnlocked = true;
                    return true;
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Windows Hello Authentication error: {ex.Message}");
                // Fallback to unlocked state if biometrics API fails to load
                _isUnlocked = true;
                return true;
            }
        }

        public void Lock()
        {
            _isUnlocked = false;
        }
    }
}
