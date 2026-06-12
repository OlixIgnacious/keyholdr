using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using Keyholdr.Models;

namespace Keyholdr.Views
{
    public partial class MainWindow : Window
    {
        private List<KeyItem> _keys = new();
        private readonly SecurityManager _securityManager = new();
        private string? _selectedTag = null;

        public MainWindow()
        {
            InitializeComponent();
            LoadData();
        }

        private void LoadData()
        {
            _keys = StorageManager.LoadKeys();
            UpdateLockStatus();
            RefreshList();
            PopulateTags();
        }

        private void RefreshList()
        {
            string searchQuery = SearchBox.Text.Trim().ToLowerInvariant();

            var filtered = _keys.Where(k =>
            {
                bool matchesSearch = string.IsNullOrEmpty(searchQuery) ||
                                     k.Platform.ToLowerInvariant().Contains(searchQuery) ||
                                     k.Label.ToLowerInvariant().Contains(searchQuery) ||
                                     k.Tags.Any(t => t.ToLowerInvariant().Contains(searchQuery));

                bool matchesTag = _selectedTag == null ||
                                  k.Tags.Any(t => t.Equals(_selectedTag, StringComparison.OrdinalIgnoreCase));

                return matchesSearch && matchesTag;
            }).ToList();

            KeysItemsControl.ItemsSource = filtered;
        }

        private void PopulateTags()
        {
            TagPanel.Children.Clear();

            // "All" filter pill
            var allBtn = CreateTagButton("All", _selectedTag == null);
            allBtn.Click += (s, e) =>
            {
                _selectedTag = null;
                RefreshList();
                PopulateTags();
            };
            TagPanel.Children.Add(allBtn);

            // Fetch unique tags from metadata
            var uniqueTags = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (var key in _keys)
            {
                foreach (var tag in key.Tags)
                {
                    uniqueTags.Add(tag);
                }
            }

            foreach (var tag in uniqueTags.OrderBy(t => t))
            {
                var tagBtn = CreateTagButton(tag, _selectedTag != null && _selectedTag.Equals(tag, StringComparison.OrdinalIgnoreCase));
                tagBtn.Click += (s, e) =>
                {
                    _selectedTag = tag;
                    RefreshList();
                    PopulateTags();
                };
                TagPanel.Children.Add(tagBtn);
            }
        }

        private Button CreateTagButton(string text, bool isActive)
        {
            var border = new Border
            {
                Background = new SolidColorBrush(isActive ? Color.FromRgb(0, 122, 255) : Color.FromRgb(44, 44, 46)), // iOS blue or dark gray
                CornerRadius = new CornerRadius(12),
                Padding = new Thickness(12, 4, 12, 4),
                Margin = new Thickness(0, 0, 8, 0)
            };

            var textBlock = new TextBlock
            {
                Text = text,
                Foreground = Brushes.White,
                FontSize = 11,
                FontWeight = isActive ? FontWeights.SemiBold : FontWeights.Normal
            };

            border.Child = textBlock;

            var button = new Button
            {
                Content = border,
                Background = Brushes.Transparent,
                BorderBrush = Brushes.Transparent,
                Cursor = Cursors.Hand,
                Padding = new Thickness(0)
            };

            // Remove default WPF button template styling
            var factory = new FrameworkElementFactory(typeof(ContentPresenter));
            button.Template = new ControlTemplate(typeof(Button)) { VisualTree = factory };

            return button;
        }

        private void UpdateLockStatus()
        {
            LockStatusIndicator.Text = _securityManager.IsUnlocked ? "🔓" : "🔑";
            LockStatusIndicator.ToolTip = _securityManager.IsUnlocked ? "Unlocked (Click to Lock)" : "Locked";
        }

        private async void LockStatusIndicator_Click(object sender, MouseButtonEventArgs e)
        {
            if (_securityManager.IsUnlocked)
            {
                _securityManager.Lock();
                UpdateLockStatus();
                MessageBox.Show(this, "Session auto-locked.", "Keyholdr", MessageBoxButton.OK, MessageBoxImage.Information);
            }
            else
            {
                if (await _securityManager.AuthenticateAsync("unlock Keyholdr session"))
                {
                    UpdateLockStatus();
                }
            }
        }

        private void SearchBox_TextChanged(object sender, TextChangedEventArgs e)
        {
            RefreshList();
        }

        private void Window_Deactivated(object sender, EventArgs e)
        {
            // Lock and hide the window on blur (Clicking elsewhere)
            _securityManager.Lock();
            UpdateLockStatus();
            this.Hide();
        }

        // Action: Copy Key
        private async void CopyKeyButton_Click(object sender, RoutedEventArgs e)
        {
            if (sender is Button btn && btn.Tag is Guid id)
            {
                var item = _keys.FirstOrDefault(k => k.Id == id);
                if (item == null) return;

                if (await _securityManager.AuthenticateAsync($"copy the key for {item.Platform}"))
                {
                    UpdateLockStatus();
                    string? secret = CredentialHelper.Retrieve(id);
                    if (secret != null)
                    {
                        Clipboard.SetText(secret);
                        MessageBox.Show(this, $"Key for {item.Platform} copied to clipboard!", "Keyholdr", MessageBoxButton.OK, MessageBoxImage.Information);
                    }
                    else
                    {
                        MessageBox.Show(this, "Failed to retrieve secret key from Credential Locker.", "Error", MessageBoxButton.OK, MessageBoxImage.Warning);
                    }
                }
            }
        }

        // Action: Reveal Key
        private async void RevealKeyButton_Click(object sender, RoutedEventArgs e)
        {
            if (sender is Button btn && btn.Tag is Guid id)
            {
                var item = _keys.FirstOrDefault(k => k.Id == id);
                if (item == null) return;

                if (await _securityManager.AuthenticateAsync($"reveal the key for {item.Platform}"))
                {
                    UpdateLockStatus();
                    string? secret = CredentialHelper.Retrieve(id);
                    if (secret != null)
                    {
                        MessageBox.Show(this, $"Platform: {item.Platform}\nLabel: {item.Label}\n\nKey:\n{secret}", "Secure Key Reveal", MessageBoxButton.OK, MessageBoxImage.Information);
                    }
                    else
                    {
                        MessageBox.Show(this, "Failed to retrieve secret key.", "Error", MessageBoxButton.OK, MessageBoxImage.Warning);
                    }
                }
            }
        }

        // Action: Toggle inline Add Form
        private void AddKeyButton_Click(object sender, RoutedEventArgs e)
        {
            // Clear inputs
            FormPlatformInput.Text = "";
            FormLabelInput.Text = "";
            FormSecretInput.Clear();
            FormTagsInput.Text = "";
            
            FormTitle.Text = "Add Secure Key";
            MainListPanel.Visibility = Visibility.Collapsed;
            AddKeyPanel.Visibility = Visibility.Visible;
        }

        private void FormCancel_Click(object sender, RoutedEventArgs e)
        {
            AddKeyPanel.Visibility = Visibility.Collapsed;
            MainListPanel.Visibility = Visibility.Visible;
        }

        private void FormSave_Click(object sender, RoutedEventArgs e)
        {
            string platform = FormPlatformInput.Text.Trim();
            string label = FormLabelInput.Text.Trim();
            string secret = FormSecretInput.Password.Trim();
            var tags = FormTagsInput.Text.Split(',')
                .Select(t => t.Trim())
                .Where(t => !string.IsNullOrEmpty(t))
                .ToList();

            if (string.IsNullOrEmpty(platform) || string.IsNullOrEmpty(secret))
            {
                MessageBox.Show(this, "Platform Name and Key Value are required.", "Validation Error", MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            var newItem = new KeyItem(platform, string.IsNullOrEmpty(label) ? "default" : label, tags);

            // Save secret in Credential Locker
            if (CredentialHelper.Save(secret, newItem.Id))
            {
                // Save metadata in JSON
                _keys.Add(newItem);
                StorageManager.SaveKeys(_keys);

                // Refresh UI
                LoadData();

                // Toggle views
                AddKeyPanel.Visibility = Visibility.Collapsed;
                MainListPanel.Visibility = Visibility.Visible;
            }
            else
            {
                MessageBox.Show(this, "Failed to save secure key to Credential Locker.", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }
    }
}
