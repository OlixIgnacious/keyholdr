using System;
using System.Drawing;
using System.Windows;
using Forms = System.Windows.Forms;
using KeyHolder.Views;

namespace KeyHolder
{
    public partial class App : Application
    {
        private Forms.NotifyIcon? _notifyIcon;
        private MainWindow? _mainWindow;

        protected override void OnStartup(StartupEventArgs e)
        {
            base.OnStartup(e);

            // Configure app to stay running in background even if all windows are closed
            ShutdownMode = ShutdownMode.OnExplicitShutdown;

            // Initialize the System Tray icon
            _notifyIcon = new Forms.NotifyIcon
            {
                Icon = CreateDynamicIcon(),
                Text = "KeyHolder",
                Visible = true
            };

            // Toggle window visibility when clicked
            _notifyIcon.Click += (s, args) =>
            {
                if (args is Forms.MouseEventArgs mouseArgs && mouseArgs.Button == Forms.MouseButtons.Left)
                {
                    ToggleWindow();
                }
            };

            // Set up context menu
            var contextMenu = new Forms.ContextMenuStrip();
            contextMenu.Items.Add("Open KeyHolder", null, (s, args) => ShowWindow());
            contextMenu.Items.Add("-");
            contextMenu.Items.Add("Exit", null, (s, args) => ShutdownApp());
            _notifyIcon.ContextMenuStrip = contextMenu;
        }

        private void ToggleWindow()
        {
            if (_mainWindow != null && _mainWindow.IsVisible)
            {
                _mainWindow.Hide();
            }
            else
            {
                ShowWindow();
            }
        }

        private void ShowWindow()
        {
            if (_mainWindow == null)
            {
                _mainWindow = new MainWindow();
                _mainWindow.Closed += (s, args) => _mainWindow = null;
            }

            // Position the popup window elegantly relative to the Taskbar position
            var workingArea = System.Windows.SystemParameters.WorkArea;
            var mousePos = Forms.Control.MousePosition;

            // Default popup positioning (bottom right above tray)
            double left = workingArea.Right - _mainWindow.Width - 10;
            double top = workingArea.Bottom - _mainWindow.Height - 10;

            // Dynamic adjustment depending on taskbar location (top, left, right)
            if (mousePos.Y < workingArea.Top + 100)
            {
                // Taskbar is at the top
                top = workingArea.Top + 10;
            }
            else if (mousePos.X < workingArea.Left + 100)
            {
                // Taskbar is on the left
                left = workingArea.Left + 10;
            }
            else if (mousePos.X > workingArea.Right - 100)
            {
                // Taskbar is on the right
                left = workingArea.Right - _mainWindow.Width - 10;
            }

            _mainWindow.Left = left;
            _mainWindow.Top = top;
            _mainWindow.Show();
            _mainWindow.Activate();
        }

        private void ShutdownApp()
        {
            if (_notifyIcon != null)
            {
                _notifyIcon.Visible = false;
                _notifyIcon.Dispose();
            }
            Shutdown();
        }

        protected override void OnExit(ExitEventArgs e)
        {
            base.OnExit(e);

            if (_notifyIcon != null)
            {
                _notifyIcon.Visible = false;
                _notifyIcon.Dispose();
            }
        }

        private Icon CreateDynamicIcon()
        {
            // Dynamically draw a premium golden key icon to prevent dependency on static file assets
            using (var bitmap = new Bitmap(32, 32))
            using (var g = Graphics.FromImage(bitmap))
            {
                g.Clear(Color.Transparent);
                g.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.AntiAlias;

                // Gold color matching macOS key logo
                using (var pen = new Pen(Color.FromArgb(255, 251, 191, 36), 3f))
                {
                    // Key head (circular loop)
                    g.DrawEllipse(pen, 10, 4, 12, 12);
                    // Key shaft
                    g.DrawLine(pen, 16, 16, 16, 28);
                    // Key teeth
                    g.DrawLine(pen, 16, 22, 22, 22);
                    g.DrawLine(pen, 16, 26, 20, 26);
                }

                return Icon.FromHandle(bitmap.GetHicon());
            }
        }
    }
}
