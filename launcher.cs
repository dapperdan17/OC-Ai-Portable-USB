using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Text;
using System.Windows.Forms;

static class Launcher
{
    // ─── JSON helpers ───
    // The launcher targets .NET Framework 4.0 (shipped with Windows), which has
    // no System.Text.Json or Newtonsoft. These small helpers produce valid JSON
    // without string-concatenation escaping bugs.

    static string EscapeJsonString(string s)
    {
        if (s == null) return "";
        var sb = new StringBuilder(s.Length + 16);
        foreach (char c in s)
        {
            switch (c)
            {
                case '\\': sb.Append("\\\\"); break;
                case '"':  sb.Append("\\\""); break;
                case '\n': sb.Append("\\n");  break;
                case '\r': sb.Append("\\r");  break;
                case '\t': sb.Append("\\t");  break;
                case '\0': sb.Append("\\0");  break;
                default:
                    // Control characters U+0000..U+001F must be escaped per RFC 8259.
                    if (c < 0x20) sb.AppendFormat("\\u{0:x4}", (int)c);
                    else sb.Append(c);
                    break;
            }
        }
        return sb.ToString();
    }

    static string BuildConfigJson(string providerId, string apiKey)
    {
        return "{\n" +
               "  \"$schema\": \"https://opencode.ai/config.json\",\n" +
               "  \"provider\": {\n" +
               "    \"" + providerId + "\": {\n" +
               "      \"options\": {\n" +
               "        \"apiKey\": \"" + EscapeJsonString(apiKey) + "\"\n" +
               "      }\n" +
               "    }\n" +
               "  }\n" +
               "}";
    }

    static void Main()
    {
        string dir = Path.GetDirectoryName(typeof(Launcher).Assembly.Location);
        string configPath = Path.Combine(dir, "data", "config", "opencode.json");

        // Check if API key is already configured
        if (!HasApiKey(configPath))
        {
            ShowApiKeyDialog(configPath, dir);
        }

        // Launch the batch file
        string bat = Path.Combine(dir, "launcher.bat");
        if (File.Exists(bat))
        {
            Process.Start(new ProcessStartInfo
            {
                FileName = bat,
                WorkingDirectory = dir,
                UseShellExecute = false,
                CreateNoWindow = true
            });
        }
    }

    static bool HasApiKey(string configPath)
    {
        if (!File.Exists(configPath))
        {
            // Try to restore from backup
            string backupPath = Path.Combine(Path.GetDirectoryName(configPath), "apikey.backup");
            if (File.Exists(backupPath))
            {
                string backupKey = File.ReadAllText(backupPath).Trim();
                if (!string.IsNullOrEmpty(backupKey))
                {
                    File.WriteAllText(configPath, BuildConfigJson("opencode", backupKey));
                    File.SetAttributes(configPath, File.GetAttributes(configPath) | FileAttributes.ReadOnly);
                    return true;
                }
            }
            return false;
        }

        // Check if read-only was removed and file was modified
        string content = File.ReadAllText(configPath);
        bool hasKey = content.Contains("\"apiKey\"") && !content.Contains("\"apiKey\": \"\"");

        if (!hasKey)
        {
            // Key was deleted - try to restore from backup
            string backupPath = Path.Combine(Path.GetDirectoryName(configPath), "apikey.backup");
            if (File.Exists(backupPath))
            {
                string backupKey = File.ReadAllText(backupPath).Trim();
                if (!string.IsNullOrEmpty(backupKey))
                {
                    // Remove read-only to restore
                    File.SetAttributes(configPath, File.GetAttributes(configPath) & ~FileAttributes.ReadOnly);

                    // Find existing provider or use default
                    string providerId = "opencode";
                    if (content.Contains("\"provider\""))
                    {
                        var match = System.Text.RegularExpressions.Regex.Match(content, "\"provider\"\\s*:\\s*\\{[^}]*\"([^\"]+)\"");
                        if (match.Success) providerId = match.Groups[1].Value;
                    }

                    File.WriteAllText(configPath, BuildConfigJson(providerId, backupKey));
                    File.SetAttributes(configPath, File.GetAttributes(configPath) | FileAttributes.ReadOnly);
                    return true;
                }
            }
        }

        return hasKey;
    }

    static void ShowApiKeyDialog(string configPath, string usbRoot)
    {
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);

        var form = new Form();
        form.Text = "OpenCode AI - API Key Setup";
        form.Size = new Size(520, 480);
        form.StartPosition = FormStartPosition.CenterScreen;
        form.FormBorderStyle = FormBorderStyle.FixedDialog;
        form.MaximizeBox = false;
        form.MinimizeBox = false;
        form.BackColor = Color.FromArgb(30, 30, 30);
        form.ForeColor = Color.White;

        // Title
        var titleLabel = new Label();
        titleLabel.Text = "OpenCode AI - First Time Setup";
        titleLabel.Font = new Font("Segoe UI", 14, FontStyle.Bold);
        titleLabel.ForeColor = Color.FromArgb(0, 200, 83);
        titleLabel.Location = new Point(20, 15);
        titleLabel.AutoSize = true;
        form.Controls.Add(titleLabel);

        // Instructions
        var infoLabel = new Label();
        infoLabel.Text = "To use OpenCode AI, you need an API key from a provider.\n\n" +
                         "1. Choose your provider below\n" +
                         "2. Click the link to sign up / get your API key\n" +
                         "3. Paste your API key in the box below\n" +
                         "4. Click OK to continue";
        infoLabel.Font = new Font("Segoe UI", 9);
        infoLabel.ForeColor = Color.FromArgb(200, 200, 200);
        infoLabel.Location = new Point(20, 55);
        infoLabel.Size = new Size(460, 100);
        form.Controls.Add(infoLabel);

        // Provider dropdown
        var providerLabel = new Label();
        providerLabel.Text = "Select Provider:";
        providerLabel.Font = new Font("Segoe UI", 9, FontStyle.Bold);
        providerLabel.Location = new Point(20, 165);
        providerLabel.AutoSize = true;
        form.Controls.Add(providerLabel);

        var providerCombo = new ComboBox();
        providerCombo.Items.AddRange(new object[] {
            "OpenCode Zen (opencode.ai)",
            "Anthropic (console.anthropic.com)",
            "OpenAI (platform.openai.com)",
            "Google (aistudio.google.com)"
        });
        providerCombo.SelectedIndex = 0;
        providerCombo.Font = new Font("Segoe UI", 9);
        providerCombo.Location = new Point(20, 185);
        providerCombo.Size = new Size(460, 25);
        providerCombo.DropDownStyle = ComboBoxStyle.DropDownList;
        form.Controls.Add(providerCombo);

        // Link label
        var linkLabel = new LinkLabel();
        linkLabel.Text = "Click here to get your API key";
        linkLabel.Font = new Font("Segoe UI", 9);
        linkLabel.Location = new Point(20, 220);
        linkLabel.AutoSize = true;
        linkLabel.LinkColor = Color.FromArgb(100, 180, 255);
        linkLabel.Click += (s, e) =>
        {
            string url = GetProviderUrl(providerCombo.SelectedIndex);
            Process.Start(new ProcessStartInfo(url) { UseShellExecute = true });
        };
        form.Controls.Add(linkLabel);

        // Update link when provider changes
        providerCombo.SelectedIndexChanged += (s, e) =>
        {
            string url = GetProviderUrl(providerCombo.SelectedIndex);
            linkLabel.Text = "Click here to get your " + GetProviderName(providerCombo.SelectedIndex) + " API key";
        };

        // API Key input
        var keyLabel = new Label();
        keyLabel.Text = "Paste your API key:";
        keyLabel.Font = new Font("Segoe UI", 9, FontStyle.Bold);
        keyLabel.Location = new Point(20, 255);
        keyLabel.AutoSize = true;
        form.Controls.Add(keyLabel);

        var keyInput = new TextBox();
        keyInput.Font = new Font("Consolas", 10);
        keyInput.Location = new Point(20, 278);
        keyInput.Size = new Size(460, 25);
        keyInput.BackColor = Color.FromArgb(50, 50, 50);
        keyInput.ForeColor = Color.White;
        keyInput.UseSystemPasswordChar = true;
        form.Controls.Add(keyInput);

        // Show/Hide password checkbox
        var showKeyCheckbox = new CheckBox();
        showKeyCheckbox.Text = "Show API key";
        showKeyCheckbox.Font = new Font("Segoe UI", 8);
        showKeyCheckbox.Location = new Point(20, 310);
        showKeyCheckbox.AutoSize = true;
        showKeyCheckbox.ForeColor = Color.FromArgb(180, 180, 180);
        showKeyCheckbox.CheckedChanged += (s, e) =>
        {
            keyInput.UseSystemPasswordChar = !showKeyCheckbox.Checked;
        };
        form.Controls.Add(showKeyCheckbox);

        // Warning label
        var warningLabel = new Label();
        warningLabel.Text = "Your API key is stored on this USB only.\nIt is never sent to any device or stored on any computer.";
        warningLabel.Font = new Font("Segoe UI", 8, FontStyle.Italic);
        warningLabel.ForeColor = Color.FromArgb(150, 150, 150);
        warningLabel.Location = new Point(20, 335);
        warningLabel.Size = new Size(460, 35);
        form.Controls.Add(warningLabel);

        // OK button
        var okButton = new Button();
        okButton.Text = "OK - Start OpenCode";
        okButton.Font = new Font("Segoe UI", 10, FontStyle.Bold);
        okButton.BackColor = Color.FromArgb(0, 200, 83);
        okButton.ForeColor = Color.Black;
        okButton.Location = new Point(20, 385);
        okButton.Size = new Size(300, 40);
        okButton.FlatStyle = FlatStyle.Flat;
        okButton.Click += (s, e) =>
        {
            if (string.IsNullOrWhiteSpace(keyInput.Text))
            {
                MessageBox.Show("Please enter an API key, or close this window to skip.",
                    "No API Key", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }

            SaveApiKey(configPath, providerCombo.SelectedIndex, keyInput.Text.Trim());
            form.Close();
        };
        form.Controls.Add(okButton);

        // Skip button
        var skipButton = new Button();
        skipButton.Text = "Skip (No Key)";
        skipButton.Font = new Font("Segoe UI", 9);
        skipButton.BackColor = Color.FromArgb(80, 80, 80);
        skipButton.ForeColor = Color.White;
        skipButton.Location = new Point(340, 385);
        skipButton.Size = new Size(140, 40);
        skipButton.FlatStyle = FlatStyle.Flat;
        skipButton.Click += (s, e) =>
        {
            form.Close();
        };
        form.Controls.Add(skipButton);

        // Handle form closing (X button)
        form.FormClosing += (s, e) =>
        {
            // Allow closing - user can skip
        };

        Application.Run(form);
    }

    static string GetProviderUrl(int index)
    {
        switch (index)
        {
            case 0: return "https://opencode.ai/auth";
            case 1: return "https://console.anthropic.com/settings/keys";
            case 2: return "https://platform.openai.com/api-keys";
            case 3: return "https://aistudio.google.com/apikey";
            default: return "https://opencode.ai/auth";
        }
    }

    static string GetProviderName(int index)
    {
        switch (index)
        {
            case 0: return "OpenCode Zen";
            case 1: return "Anthropic";
            case 2: return "OpenAI";
            case 3: return "Google";
            default: return "OpenCode Zen";
        }
    }

    static string GetProviderId(int index)
    {
        switch (index)
        {
            case 0: return "opencode";
            case 1: return "anthropic";
            case 2: return "openai";
            case 3: return "google";
            default: return "opencode";
        }
    }

    static void SaveApiKey(string configPath, int providerIndex, string apiKey)
    {
        string providerId = GetProviderId(providerIndex);
        string dir = Path.GetDirectoryName(configPath);
        if (!Directory.Exists(dir)) Directory.CreateDirectory(dir);

        string json;
        if (File.Exists(configPath))
        {
            File.SetAttributes(configPath, File.GetAttributes(configPath) & ~FileAttributes.ReadOnly);
            json = File.ReadAllText(configPath);
        }
        else
        {
            json = "{\n  \"$schema\": \"https://opencode.ai/config.json\"\n}";
        }

        string escaped = EscapeJsonString(apiKey);
        string providerSection = "\"" + providerId + "\"";

        if (json.Contains(providerSection) && json.Contains("\"apiKey\""))
        {
            // Replace existing apiKey value
            json = System.Text.RegularExpressions.Regex.Replace(json,
                "\"apiKey\"\\s*:\\s*\"[^\"]*\"",
                "\"apiKey\": \"" + escaped + "\"");
        }
        else if (json.Contains("\"provider\""))
        {
            // Provider section exists but no apiKey — insert after "provider": {
            json = json.Replace("\"provider\": {",
                "\"provider\": {\n    \"" + providerId + "\": {\n      \"options\": {\n        \"apiKey\": \"" + escaped + "\"\n      }\n    },");
        }
        else
        {
            // No provider section at all
            json = json.TrimEnd('}', ' ', '\n', '\r') +
                ",\n  \"provider\": {\n    \"" + providerId + "\": {\n      \"options\": {\n        \"apiKey\": \"" + escaped + "\"\n      }\n    }\n  }\n}";
        }

        File.WriteAllText(configPath, json);
        File.SetAttributes(configPath, File.GetAttributes(configPath) | FileAttributes.ReadOnly);

        string backupPath = Path.Combine(dir, "apikey.backup");
        File.WriteAllText(backupPath, apiKey);
        File.SetAttributes(backupPath, File.GetAttributes(backupPath) | FileAttributes.Hidden | FileAttributes.ReadOnly);
    }
}
