using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Text;
using System.IO;
using System.IO.Compression;
using System.Management;
using System.Reflection;
using System.Security.Principal;
using System.Text;
using System.Threading;
using System.Windows.Forms;

namespace OpenCodeUsbCreator
{
    static class Program
    {
        // How long the splash stays up before the main window is built.
        const double SplashSeconds = 5.0;

        [STAThread]
        static void Main()
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);

            if (!IsAdministrator())
            {
                MessageBox.Show(
                    "This tool requires Administrator privileges to partition and format USB drives.\n\n" +
                    "Please restart the application 'As Administrator'.",
                    "Administrator Privileges Required",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Warning);
                return;
            }

            string dir = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location);
            string pngPath = Path.Combine(dir, "7bf66f2c-a3a5-4b4b-8c78-0f019bf0d339.png");
            string icoPath = Path.Combine(dir, "opencode-usb-creator.ico");

            using (SplashForm splash = new SplashForm(pngPath, icoPath))
            {
                splash.Show();

                // Keep the splash up for a fixed spell before building the main
                // window. SplashForm starts at Opacity 0 and fades in on a 30ms
                // timer, so it needs the message loop pumped for ~400ms just to
                // become visible; a single DoEvents() followed by Hide() meant it
                // never appeared at all. Pump in small slices so the fade runs and
                // the window stays responsive rather than looking hung.
                DateTime splashUntil = DateTime.Now.AddSeconds(SplashSeconds);
                while (DateTime.Now < splashUntil)
                {
                    Application.DoEvents();
                    Thread.Sleep(15);
                }

                using (MainForm main = new MainForm(pngPath, icoPath))
                {
                    splash.Hide();
                    main.ShowDialog();
                    splash.SetStatus("Done!");
                    splash.TopMost = true;
                    splash.Show();
                    Application.DoEvents();
                }
            }
        }

        static bool IsAdministrator()
        {
            try
            {
                using (WindowsIdentity identity = WindowsIdentity.GetCurrent())
                {
                    WindowsPrincipal principal = new WindowsPrincipal(identity);
                    return principal.IsInRole(WindowsBuiltInRole.Administrator);
                }
            }
            catch { return false; }
        }
    }

    public class SplashForm : Form
    {
        Label _status;
        bool _closed;

        public SplashForm(string pngPath, string icoPath)
        {
            FormBorderStyle = FormBorderStyle.None;
            StartPosition = FormStartPosition.CenterScreen;
            ShowInTaskbar = false;
            TopMost = true;
            Width = 440;
            Height = 520;
            BackColor = Color.FromArgb(18, 18, 28);
            DoubleBuffered = true;

            Paint += (s, e) =>
            {
                e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
                using (Pen p = new Pen(Color.FromArgb(60, 80, 180, 255), 2))
                {
                    Rectangle r = new Rectangle(1, 1, ClientSize.Width - 3, ClientSize.Height - 3);
                    e.Graphics.DrawRectangle(p, r);
                }
            };

            PictureBox pb = new PictureBox
            {
                SizeMode = PictureBoxSizeMode.Zoom,
                Width = 300,
                Height = 300,
                BackColor = Color.Transparent,
                Location = new Point((Width - 300) / 2, 40)
            };

            if (File.Exists(pngPath))
            {
                try { pb.Image = Image.FromFile(pngPath); }
                catch { }
            }
            if (pb.Image == null && File.Exists(icoPath))
            {
                try { using (Icon ico = new Icon(icoPath, 256, 256)) pb.Image = ico.ToBitmap(); }
                catch { }
            }
            // Final fallback: the copy embedded in this executable. Both paths above
            // read from disk next to the exe, which is fine when running from the
            // build folder but leaves the splash blank for anyone who downloads
            // create-usb.exe on its own - which is how it is distributed.
            if (pb.Image == null)
            {
                try
                {
                    using (Stream es = Assembly.GetExecutingAssembly().GetManifestResourceStream("splash.png"))
                        if (es != null) pb.Image = Image.FromStream(es);
                }
                catch { }
            }

            Label title = new Label
            {
                Text = "OpenCode AI",
                Font = new Font("Segoe UI", 22, FontStyle.Bold),
                ForeColor = Color.FromArgb(120, 200, 255),
                BackColor = Color.Transparent,
                TextAlign = ContentAlignment.MiddleCenter,
                Width = 400, Height = 44,
                Location = new Point((Width - 400) / 2, 350)
            };

            Label sub = new Label
            {
                Text = "Portable USB Installer",
                Font = new Font("Segoe UI", 12, FontStyle.Regular),
                ForeColor = Color.FromArgb(190, 190, 220),
                BackColor = Color.Transparent,
                TextAlign = ContentAlignment.MiddleCenter,
                Width = 400, Height = 26,
                Location = new Point((Width - 400) / 2, 395)
            };

            _status = new Label
            {
                Text = "Loading...",
                Font = new Font("Segoe UI", 9, FontStyle.Italic),
                ForeColor = Color.FromArgb(150, 150, 190),
                BackColor = Color.Transparent,
                TextAlign = ContentAlignment.MiddleCenter,
                Width = 400, Height = 20,
                Location = new Point((Width - 400) / 2, 430),
                AutoEllipsis = true
            };

            Controls.Add(pb); Controls.Add(title); Controls.Add(sub); Controls.Add(_status);

            Opacity = 0;
            System.Windows.Forms.Timer fade = new System.Windows.Forms.Timer { Interval = 30 };
            fade.Tick += (s, e) => { if (Opacity < 1.0) Opacity += 0.08; else fade.Stop(); };
            fade.Start();

            FormClosing += (s, e) => _closed = true;
        }

        public void SetStatus(string text)
        {
            if (_closed || _status == null || _status.IsDisposed) return;
            try
            {
                if (InvokeRequired) { Invoke(new Action<string>(SetStatus), text); return; }
                _status.Text = text;
            }
            catch { }
        }

        protected override bool ShowWithoutActivation { get { return true; } }
    }

    public class MainForm : Form
    {
        string _pngPath, _icoPath;
        ComboBox _cmbUsb;
        RadioButton _rbSingle, _rbTwo, _rbCustom, _rbSkip, _rbMbr, _rbGpt;
        NumericUpDown _nudSize;
        TextBox _txtLabel1, _txtLabel2;
        ProgressBar _progress;
        Label _lblStatus;
        RichTextBox _txtLog;
        Button _btnCreate, _btnCancel;
        Panel _partDetails;

        int _diskNum = -1;
        bool _running, _cancelled;
        bool UseGpt { get { return _rbGpt.Checked; } }

        public MainForm(string pngPath, string icoPath)
        {
            _pngPath = pngPath;
            _icoPath = icoPath;

            Text = "OpenCode AI - Portable USB Installer";
            ClientSize = new Size(760, 620);
            StartPosition = FormStartPosition.CenterScreen;
            MinimizeBox = false;
            MaximizeBox = false;
            FormBorderStyle = FormBorderStyle.FixedDialog;
            BackColor = Color.FromArgb(22, 22, 34);
            Font = new Font("Segoe UI", 9.5f);

            if (File.Exists(icoPath))
            {
                try { Icon = new Icon(icoPath, 32, 32); } catch { }
            }

            BuildUI();
            EnumerateUsb();
        }

        void BuildUI()
        {
            // ─── IMAGE HEADER ───
            PictureBox headerPic = new PictureBox
            {
                SizeMode = PictureBoxSizeMode.Zoom,
                Width = 120,
                Height = 120,
                BackColor = Color.Transparent,
                Location = new Point(20, 16)
            };
            if (File.Exists(_pngPath))
            {
                try { headerPic.Image = Image.FromFile(_pngPath); } catch { }
            }
            if (headerPic.Image == null && File.Exists(_icoPath))
            {
                try { using (Icon ico = new Icon(_icoPath, 64, 64)) headerPic.Image = ico.ToBitmap(); } catch { }
            }

            Label headerTitle = new Label
            {
                Text = "OpenCode AI",
                Font = new Font("Segoe UI", 20, FontStyle.Bold),
                ForeColor = Color.FromArgb(120, 200, 255),
                BackColor = Color.Transparent,
                Location = new Point(158, 28),
                AutoSize = true
            };
            Label headerSub = new Label
            {
                Text = "Portable USB Installer  —  Creates a fully-configured OpenCode AI USB drive",
                Font = new Font("Segoe UI", 10),
                ForeColor = Color.FromArgb(180, 180, 210),
                BackColor = Color.Transparent,
                Location = new Point(160, 60),
                AutoSize = true
            };

            Panel headerPanel = new Panel
            {
                BackColor = Color.FromArgb(30, 30, 48),
                Location = new Point(0, 0),
                Width = ClientSize.Width,
                Height = 150
            };
            headerPanel.Controls.Add(headerPic);
            headerPanel.Controls.Add(headerTitle);
            headerPanel.Controls.Add(headerSub);

            // Divider
            Panel divider = new Panel
            {
                BackColor = Color.FromArgb(50, 50, 70),
                Location = new Point(16, 158),
                Width = ClientSize.Width - 32,
                Height = 1
            };

            // ─── TARGET USB ───
            int y = 172;
            Label lblUsb = new Label { Text = "Target USB:", Location = new Point(22, y + 4), AutoSize = true, ForeColor = Color.FromArgb(230, 230, 250), BackColor = Color.Transparent, Font = new Font("Segoe UI", 9.5f, FontStyle.Bold) };
            _cmbUsb = new ComboBox { Location = new Point(130, y), Width = 490, Height = 24, DropDownStyle = ComboBoxStyle.DropDownList, BackColor = Color.FromArgb(38, 38, 52), ForeColor = Color.FromArgb(200, 220, 255), FlatStyle = FlatStyle.Flat };
            _cmbUsb.SelectedIndexChanged += (s, e) => { var info = _cmbUsb.SelectedItem as UsbInfo; _diskNum = info != null ? info.Index : -1; };

            y += 30;

            // ─── PARTITION STYLE ───
            Label lblStyle = new Label { Text = "Style:", Location = new Point(22, y + 4), AutoSize = true, ForeColor = Color.FromArgb(230, 230, 250), BackColor = Color.Transparent, Font = new Font("Segoe UI", 9.5f, FontStyle.Bold) };
            _rbMbr = CreateRadio("MBR", 130, y, true);
            _rbGpt = CreateRadio("GPT", 190, y, false);
            Controls.Add(lblStyle); Controls.Add(_rbMbr); Controls.Add(_rbGpt);

            y += 24;

            // ─── PARTITION OPTIONS ───
            Label lblPart = new Label { Text = "Partitioning:", Location = new Point(22, y + 4), AutoSize = true, ForeColor = Color.FromArgb(230, 230, 250), BackColor = Color.Transparent, Font = new Font("Segoe UI", 9.5f, FontStyle.Bold) };

            Panel partPanel = new Panel { Location = new Point(130, y), Width = 490, Height = 86, BackColor = Color.Transparent };
            _rbSingle = CreateRadio("Single partition (entire drive)", 0, 0, true);
            _rbTwo = CreateRadio("Two partitions: Tools (50%) + Storage", 0, 22, false);
            _rbCustom = CreateRadio("Custom partition size", 0, 44, false);
            _rbSkip = CreateRadio("Skip (drive already partitioned)", 0, 66, false);

            foreach (RadioButton rb in new[] { _rbSingle, _rbTwo, _rbCustom, _rbSkip })
            {
                rb.CheckedChanged += (s, e) => ToggleCustom();
                partPanel.Controls.Add(rb);
            }

            _partDetails = new Panel { Location = new Point(270, 0), Width = 230, Height = 90, BackColor = Color.Transparent, Visible = false };
            Label lblSz = new Label { Text = "Size (GB):", Location = new Point(0, 6), AutoSize = true, ForeColor = Color.FromArgb(220, 220, 245) };
            _nudSize = new NumericUpDown { Location = new Point(100, 4), Width = 55, Minimum = 10, Maximum = 999, Value = 37, BackColor = Color.FromArgb(38, 38, 52), ForeColor = Color.FromArgb(200, 220, 255) };
            Label lblL1 = new Label { Text = "Tools label:", Location = new Point(0, 34), AutoSize = true, ForeColor = Color.FromArgb(220, 220, 245) };
            _txtLabel1 = new TextBox { Text = "OpenCode AI", Location = new Point(100, 32), Width = 130, BackColor = Color.FromArgb(38, 38, 52), ForeColor = Color.FromArgb(200, 220, 255), BorderStyle = BorderStyle.FixedSingle };
            Label lblL2 = new Label { Text = "Storage label:", Location = new Point(0, 62), AutoSize = true, ForeColor = Color.FromArgb(220, 220, 245) };
            _txtLabel2 = new TextBox { Text = "Storage", Location = new Point(100, 60), Width = 130, BackColor = Color.FromArgb(38, 38, 52), ForeColor = Color.FromArgb(200, 220, 255), BorderStyle = BorderStyle.FixedSingle };
            _partDetails.Controls.AddRange(new Control[] { lblSz, _nudSize, lblL1, _txtLabel1, lblL2, _txtLabel2 });
            partPanel.Controls.Add(_partDetails);

            y += 92;

            // ─── PROGRESS ───
            Label lblProg = new Label { Text = "Progress:", Location = new Point(22, y + 4), AutoSize = true, ForeColor = Color.FromArgb(230, 230, 250), BackColor = Color.Transparent, Font = new Font("Segoe UI", 9.5f, FontStyle.Bold) };
            _progress = new ProgressBar { Location = new Point(130, y + 2), Width = 490, Height = 22, Style = ProgressBarStyle.Continuous };

            y += 30;

            // ─── STATUS ───
            Label lblStat = new Label { Text = "Status:", Location = new Point(22, y + 4), AutoSize = true, ForeColor = Color.FromArgb(230, 230, 250), BackColor = Color.Transparent, Font = new Font("Segoe UI", 9.5f, FontStyle.Bold) };
            _lblStatus = new Label { Location = new Point(130, y + 2), Width = 490, Height = 22, BackColor = Color.FromArgb(30, 30, 44), ForeColor = Color.FromArgb(200, 220, 255), AutoEllipsis = true, Text = "Ready. Select USB drive and click 'Create USB'.", Padding = new Padding(4, 3, 4, 3) };

            y += 28;

            // ─── LOG ───
            Label lblLog = new Label { Text = "Log:", Location = new Point(22, y + 4), AutoSize = true, ForeColor = Color.FromArgb(230, 230, 250), Font = new Font("Segoe UI", 9.5f, FontStyle.Bold) };
            _txtLog = new RichTextBox { Location = new Point(22, y + 22), Width = ClientSize.Width - 44, Height = 190, BackColor = Color.FromArgb(16, 16, 26), ForeColor = Color.FromArgb(180, 220, 180), ReadOnly = true, Font = new Font("Consolas", 8.5f), BorderStyle = BorderStyle.None };

            y += 218;

            // ─── BUTTONS ───
            _btnCreate = new Button
            {
                Text = "CREATE USB",
                Location = new Point(ClientSize.Width - 260, y),
                Width = 110, Height = 32,
                BackColor = Color.FromArgb(45, 130, 70),
                ForeColor = Color.White,
                FlatStyle = FlatStyle.Flat,
                Font = new Font("Segoe UI", 9, FontStyle.Bold)
            };
            _btnCreate.FlatAppearance.BorderSize = 0;
            _btnCreate.Click += (s, e) => StartCreate();

            _btnCancel = new Button
            {
                Text = "Cancel",
                Location = new Point(ClientSize.Width - 140, y),
                Width = 100, Height = 32,
                BackColor = Color.FromArgb(100, 50, 50),
                ForeColor = Color.White,
                FlatStyle = FlatStyle.Flat,
                Enabled = false
            };
            _btnCancel.FlatAppearance.BorderSize = 0;
            _btnCancel.Click += (s, e) => { _cancelled = true; _btnCancel.Enabled = false; };

            Controls.Add(headerPanel);
            Controls.Add(divider);
            Controls.Add(lblUsb); Controls.Add(_cmbUsb);
            Controls.Add(lblPart); Controls.Add(partPanel);
            Controls.Add(lblProg); Controls.Add(_progress);
            Controls.Add(lblStat); Controls.Add(_lblStatus);
            Controls.Add(lblLog); Controls.Add(_txtLog);
            Controls.Add(_btnCreate); Controls.Add(_btnCancel);
        }

        RadioButton CreateRadio(string text, int x, int y, bool check)
        {
            return new RadioButton
            {
                Text = text,
                Location = new Point(x, y),
                AutoSize = true,
                BackColor = Color.Transparent,
                ForeColor = Color.FromArgb(220, 220, 245),
                Checked = check
            };
        }

        void ToggleCustom() { _partDetails.Visible = _rbCustom.Checked; }

        // Mirror the GUI log to a file. The in-window log is destroyed the moment
        // the dialog closes, which makes any failure impossible to diagnose after
        // the fact and leaves users with nothing to attach to a bug report.
        // Deliberately NOT %TEMP% - nothing this project writes may land in a host
        // profile. This log sits next to the creator executable, which is run on
        // the owner's own machine, and travels/deletes with it.
        static readonly string LogPath = Path.Combine(
            Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location) ?? ".",
            "create-usb.log");
        static bool _logHeaderWritten = false;

        // Win32_LogicalDisk.DeviceID yields a bare "E:" with no trailing separator.
        // Path.Combine("E:", "data") produces "E:data", which Windows resolves
        // RELATIVE to the current directory on E: rather than to its root - so
        // files can land somewhere entirely unintended. Always normalise before
        // building paths from a drive root.
        static string NormRoot(string p)
        {
            if (string.IsNullOrEmpty(p)) return p;
            return p.EndsWith("\\") ? p : p + "\\";
        }

        static void LogToFile(string text)
        {
            try
            {
                if (!_logHeaderWritten)
                {
                    _logHeaderWritten = true;
                    File.AppendAllText(LogPath, Environment.NewLine
                        + "===== run started " + DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") + " =====" + Environment.NewLine);
                }
                File.AppendAllText(LogPath, DateTime.Now.ToString("HH:mm:ss.fff") + "  " + text + Environment.NewLine);
            }
            catch { }
        }

        void Log(string text, Color? color = null)
        {
            // File first, so anything logged during a crash or after the window
            // is disposed still reaches disk. The UI update is a separate method
            // because it re-enters itself via Invoke when called off the UI
            // thread - routing that through Log() would write each line twice.
            LogToFile(text);
            LogToUi(text, color);
        }

        void LogToUi(string text, Color? color)
        {
            if (_txtLog.IsDisposed) return;
            if (InvokeRequired) { Invoke(new Action<string, Color?>(LogToUi), text, color); return; }
            Color c = color ?? Color.FromArgb(200, 240, 190);
            _txtLog.SelectionStart = _txtLog.TextLength;
            _txtLog.SelectionLength = 0;
            _txtLog.SelectionColor = c;
            _txtLog.AppendText(text + "\n");
            _txtLog.ScrollToCaret();
        }

        void SetStat(string text)
        {
            if (_lblStatus.IsDisposed) return;
            if (InvokeRequired) { Invoke(new Action<string>(SetStat), text); return; }
            _lblStatus.Text = text;
        }

        void SetProg(int val)
        {
            if (_progress.IsDisposed) return;
            if (InvokeRequired) { Invoke(new Action<int>(SetProg), val); return; }
            _progress.Value = Math.Min(val, 100);
        }

        void EnumerateUsb()
        {
            _cmbUsb.Items.Clear();

            try
            {
                using (ManagementObjectSearcher s = new ManagementObjectSearcher("SELECT * FROM Win32_DiskDrive WHERE InterfaceType='USB'"))
                {
                    foreach (ManagementObject d in s.Get())
                    {
                        int idx = Convert.ToInt32(d["Index"]);
                        string model = d["Model"] as string ?? "Unknown";
                        ulong size = Convert.ToUInt64(d["Size"]);
                        double gb = Math.Round(size / 1e9, 1);

                        List<string> letters = new List<string>();
                        try
                        {
                            using (ManagementObjectSearcher ps = new ManagementObjectSearcher(
                                "ASSOCIATORS OF {Win32_DiskDrive.DeviceID='" + d["DeviceID"] + "'} WHERE AssocClass=Win32_DiskDriveToDiskPartition"))
                            {
                                foreach (ManagementObject p in ps.Get())
                                {
                                    using (ManagementObjectSearcher ls = new ManagementObjectSearcher(
                                        "ASSOCIATORS OF {Win32_DiskPartition.DeviceID='" + p["DeviceID"] + "'} WHERE AssocClass=Win32_LogicalDiskToPartition"))
                                    {
                                        foreach (ManagementObject l in ls.Get())
                                        {
                                            string vid = l["DeviceID"] as string;
                                            if (vid != null) letters.Add(vid);
                                        }
                                    }
                                }
                            }
                        }
                        catch { }

                        string vol = letters.Count > 0 ? string.Join(", ", letters) + " — " : "";
                        _cmbUsb.Items.Add(new UsbInfo { Index = idx, Model = model, SizeGB = gb, Display = "[" + idx + "] " + model + "  (" + gb + "GB)  " + vol });
                    }
                }
            }
            catch (Exception ex) { Log("USB scan error: " + ex.Message, Color.Red); }

            if (_cmbUsb.Items.Count == 0)
            {
                _cmbUsb.Items.Add("(no USB drives found)");
            }
            _cmbUsb.SelectedIndex = 0;
        }

        void StartCreate()
        {
            if (_running) return;

            if (_diskNum < 0)
            {
                MessageBox.Show("Select a target USB drive first.", "No Target", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }

            if (UsePartition())
            {
                DialogResult dr = MessageBox.Show(
                    "WARNING: ALL DATA ON THE SELECTED USB DRIVE WILL BE DESTROYED!\n\n" +
                    "This will:\n" +
                    "  - Delete all partitions on the drive\n" +
                    "  - Format the drive (exFAT)\n" +
                    "  - Create new partitions\n\n" +
                    "Make sure you have backed up any important files.\n\n" +
                    "Do you want to continue?",
                    "DESTROY ALL DATA?",
                    MessageBoxButtons.YesNo,
                    MessageBoxIcon.Warning);
                if (dr != DialogResult.Yes) return;
            }

            _running = true;
            _cancelled = false;
            _btnCreate.Enabled = false;
            _btnCancel.Enabled = true;
            _txtLog.Clear();

            ThreadPool.QueueUserWorkItem(_ => RunCreate());
        }

        class UsbInfo { public int Index; public string Model; public double SizeGB; public string Display; public override string ToString() { return Display; } }

        void RunCreate()
        {
            try
            {
                Log("═══════════════════════════════════════════", Color.Cyan);
                Log("  OpenCode AI Portable USB Installer", Color.Cyan);
                Log("═══════════════════════════════════════════", Color.Cyan);
                Log("Self-contained installer — all files embedded.", Color.White);
                SetStat("Starting...");
                SetProg(0);

                // Verify embedded resource exists
                using (Stream sz = Assembly.GetExecutingAssembly().GetManifestResourceStream("opencode-source.zip"))
                {
                    if (sz == null)
                    {
                        Log("ERROR: Embedded source archive not found.", Color.Red);
                        Fail("Corrupted installer: missing embedded resource."); return;
                    }
                }
                using (Stream lx = Assembly.GetExecutingAssembly().GetManifestResourceStream("launcher.exe"))
                {
                    if (lx == null)
                    {
                        Log("ERROR: Embedded launcher not found.", Color.Red);
                        Fail("Corrupted installer: missing launcher resource."); return;
                    }
                }
                Log("Embedded source verified.", Color.Green);

                string targetRoot = null, storageRoot = null;

                if (!UsePartition())
                {
                    targetRoot = NormRoot(FindVolume());
                    if (targetRoot == null) { Fail("Could not find target drive."); return; }
                    Log("Using existing volume: " + targetRoot, Color.Green);
                }
                else
                {
                    SetStat("Partitioning drive...");
                    SetProg(10);
                    Log("Running diskpart...", Color.White);

                    if (!RunDiskpart()) return;

                    Log("Partitioning complete. Waiting for drives...", Color.Green);
                    SetProg(15);
                    SetStat("Waiting for volumes to appear...");

                    targetRoot = null;
                    for (int retry = 0; retry < 12 && targetRoot == null; retry++)
                    {
                        Thread.Sleep(3000);
                        SetStat("Waiting for volumes... (attempt " + (retry + 1) + "/12)");
                        targetRoot = NormRoot(FindOcVolume() ?? FindVolume());
                    }

                    if (targetRoot == null)
                    {
                        Log("Could not find target drive after partitioning.", Color.Red);
                        Log("The drive may need to be assigned a letter manually in Disk Management.", Color.Yellow);
                        Fail("Target drive not found after partitioning. Check Disk Management.");
                        return;
                    }
                    SetProg(20);
                    Log("Target: " + targetRoot, Color.Green);
                    storageRoot = FindStorage(targetRoot);
                    if (storageRoot != null) Log("Storage: " + storageRoot, Color.Green);
                }

                if (_cancelled) { Log("Cancelled.", Color.Yellow); Fail("Cancelled"); return; }

                SetStat("Extracting files to USB...");
                SetProg(25);
                Log("Extracting embedded files (this may take a while)...", Color.White);
                ExtractEmbedded(targetRoot);
                SetProg(70);
                Log("Extraction complete.", Color.Green);

                if (_cancelled) { Log("Cancelled.", Color.Yellow); Fail("Cancelled"); return; }

                SetStat("Configuring USB...");
                SetProg(75);
                Configure(targetRoot);
                SetProg(90);
                ConfigFile(targetRoot);

                SetProg(100);
                SetStat("Done!");
                Log("", Color.White);
                Log("═══════════════════════════════════════════", Color.Cyan);
                Log("  USB CREATION COMPLETE", Color.Green);
                Log("═══════════════════════════════════════════", Color.Cyan);
                Log("  Target: " + targetRoot, Color.White);
                if (storageRoot != null) Log("  Storage: " + storageRoot, Color.White);
                Log("", Color.White);
                Log("  Eject safely, then plug into any Windows PC", Color.White);
                Log("  and double-click 'OpenCode AI.exe'", Color.White);

                Invoke(new Action(() => MessageBox.Show("USB creation complete!\n\nTarget: " + targetRoot + "\n\nEject safely before removing.", "Success", MessageBoxButtons.OK, MessageBoxIcon.Information)));
            }
            catch (Exception ex)
            {
                Log("ERROR: " + ex.Message, Color.Red);
                Log(ex.StackTrace, Color.DarkRed);
                Fail("Error: " + ex.Message);
            }
            finally
            {
                _running = false;
                Invoke(new Action(() => { _btnCreate.Enabled = true; _btnCancel.Enabled = false; SetStat("Ready"); }));
            }
        }

        void ExtractEmbedded(string targetRoot)
        {
            using (Stream stream = Assembly.GetExecutingAssembly().GetManifestResourceStream("opencode-source.zip"))
            using (ZipArchive archive = new ZipArchive(stream))
            {
                int total = archive.Entries.Count;
                int done = 0;
                int errors = 0;

                foreach (ZipArchiveEntry entry in archive.Entries)
                {
                    if (_cancelled) return;

                    string dest = Path.Combine(targetRoot, entry.FullName);

                    if (entry.Name == "")
                    {
                        Directory.CreateDirectory(dest);
                    }
                    else
                    {
                        Directory.CreateDirectory(Path.GetDirectoryName(dest));
                        try
                        {
                            entry.ExtractToFile(dest, true);
                        }
                        catch (Exception ex)
                        {
                            errors++;
                            if (errors <= 5) Log("Extract: " + entry.FullName + " — " + ex.Message, Color.Red);
                        }
                    }

                    done++;
                    int pct = 25 + (done * 45 / Math.Max(total, 1));
                    SetProg(Math.Min(pct, 70));
                    SetStat("Extracting: " + entry.FullName);
                }

                Log("Extracted " + done + " items (" + errors + " errors)", Color.Green);
            }
        }

        void Fail(string msg)
        {
            Invoke(new Action(() => { _lblStatus.Text = msg; MessageBox.Show(msg, "USB Installer", MessageBoxButtons.OK, MessageBoxIcon.Warning); }));
        }

        bool UsePartition() { return _rbSingle.Checked || _rbTwo.Checked || _rbCustom.Checked; }

        bool RunDiskpart()
        {
            SetStat("Partitioning drive...");
            SetProg(10);

            if (RunPowerShellPartitioning()) return true;

            Log("PowerShell partitioning failed, falling back to diskpart...", Color.Yellow);
            return RunDiskpartDirect();
        }

        bool RunPowerShellPartitioning()
        {
            string l1 = "OpenCode AI";
            string l2 = "Storage";
            int sz = 37;

            if (_rbCustom.Checked)
            {
                sz = (int)_nudSize.Value;
                l1 = _txtLabel1.Text;
                l2 = _txtLabel2.Text;
            }
            else if (_rbTwo.Checked)
            {
                var info = _cmbUsb.SelectedItem as UsbInfo;
                sz = info != null ? Math.Max(10, (int)(info.SizeGB / 2)) : 37;
            }

            string style = UseGpt ? "gpt" : "mbr";

            // Step 1: clean + convert via diskpart directly (reliable, no PowerShell pipe issues)
            //
            // 'convert gpt' converts FROM MBR, so it errors with "The disk you
            // specified is not MBR formatted" when the disk is already GPT - which
            // it always is when re-running this tool on a stick it made earlier.
            // Re-selecting the disk after the clean forces diskpart to re-read the
            // now-empty disk rather than acting on its cached pre-clean state.
            string dpScript = "select disk " + _diskNum + "\r\n"
                            + "rescan\r\n"
                            + "clean\r\n"
                            + "rescan\r\n"
                            + "select disk " + _diskNum + "\r\n"
                            + "convert " + style + "\r\n"
                            + "rescan\r\n"
                            + "exit\r\n";
            string dpFile = Path.GetTempFileName();
            File.WriteAllText(dpFile, dpScript);
            bool diskpartOk = false;
            try
            {
                Log("Running diskpart (clean + convert)...", Color.Gray);
                Process dp = new Process();
                dp.StartInfo.FileName = "diskpart.exe";
                dp.StartInfo.Arguments = "/s \"" + dpFile + "\"";
                dp.StartInfo.UseShellExecute = false;
                dp.StartInfo.RedirectStandardOutput = true;
                dp.StartInfo.RedirectStandardError = true;
                dp.StartInfo.CreateNoWindow = true;
                dp.Start();
                string dpOut = dp.StandardOutput.ReadToEnd();
                string dpErr = dp.StandardError.ReadToEnd();
                dp.WaitForExit();
                if (!string.IsNullOrEmpty(dpOut)) Log(dpOut, Color.Gray);
                if (!string.IsNullOrEmpty(dpErr)) Log(dpErr, Color.Red);
                diskpartOk = dp.ExitCode == 0;
                if (!diskpartOk)
                {
                    // A non-zero exit here is not necessarily fatal: 'convert gpt'
                    // reports failure when the disk is ALREADY gpt, which is the
                    // desired end state anyway. Only give up if the disk did not
                    // actually end up in the requested style.
                    string actual = GetDiskStyle(_diskNum);
                    if (actual != null && actual.Equals(style, StringComparison.OrdinalIgnoreCase))
                    {
                        Log("diskpart reported an error, but disk is already " + actual.ToUpper()
                            + " - continuing.", Color.Yellow);
                        diskpartOk = true;
                    }
                    else
                    {
                        Log("diskpart clean+convert failed (exit code: " + dp.ExitCode
                            + ", disk style: " + (actual ?? "unknown") + ").", Color.Red);
                        return false;
                    }
                }
                else Log("diskpart clean+convert succeeded.", Color.Green);
            }
            catch (Exception ex)
            {
                Log("diskpart error: " + ex.Message, Color.Red);
                return false;
            }
            finally { try { File.Delete(dpFile); } catch { } }

            Thread.Sleep(2000);

            // Step 2: New-Partition + Format-Volume via PowerShell
            string psCmd;
            if (_rbSingle.Checked)
            {
                psCmd = "$p = New-Partition -DiskNumber " + _diskNum + " -UseMaximumSize -AssignDriveLetter -ErrorAction Stop; " +
                        "Start-Sleep -Seconds 1; " +
                        "$v = $p | Get-Volume; " +
                        "Format-Volume -DriveLetter $v.DriveLetter -FileSystem EXFAT -NewFileSystemLabel 'OpenCode AI' -Confirm:$false -ErrorAction Stop; " +
                        "Write-Host 'OK:DONE='$v.DriveLetter";
            }
            else
            {
                psCmd = "$p1 = New-Partition -DiskNumber " + _diskNum + " -Size " + sz + "GB -AssignDriveLetter -ErrorAction Stop; " +
                        "Start-Sleep -Seconds 1; " +
                        "$v1 = $p1 | Get-Volume; " +
                        "Format-Volume -DriveLetter $v1.DriveLetter -FileSystem EXFAT -NewFileSystemLabel '" + l1 + "' -Confirm:$false -ErrorAction Stop; " +
                        "Write-Host 'OK:P1='$v1.DriveLetter; " +
                        "$p2 = New-Partition -DiskNumber " + _diskNum + " -UseMaximumSize -AssignDriveLetter -ErrorAction Stop; " +
                        "Start-Sleep -Seconds 1; " +
                        "$v2 = $p2 | Get-Volume; " +
                        "Format-Volume -DriveLetter $v2.DriveLetter -FileSystem EXFAT -NewFileSystemLabel '" + l2 + "' -Confirm:$false -ErrorAction Stop; " +
                        "Write-Host 'OK:P2='$v2.DriveLetter";
            }

            string tmp = Path.GetTempFileName() + ".ps1";
            File.WriteAllText(tmp, psCmd, Encoding.Unicode);
            try
            {
                Log("Running PowerShell partitioning...", Color.Gray);
                Log("  Script: " + tmp, Color.DarkGray);
                SetStat("Partitioning via PowerShell...");
                SetProg(12);

                Process p = new Process();
                p.StartInfo.FileName = "powershell.exe";
                p.StartInfo.Arguments = "-NoLogo -NoProfile -ExecutionPolicy Bypass -File \"" + tmp + "\"";
                p.StartInfo.UseShellExecute = false;
                p.StartInfo.RedirectStandardOutput = true;
                p.StartInfo.RedirectStandardError = true;
                p.StartInfo.CreateNoWindow = true;
                p.Start();
                string o = p.StandardOutput.ReadToEnd();
                string e = p.StandardError.ReadToEnd();
                p.WaitForExit();

                if (!string.IsNullOrEmpty(o)) Log(o, Color.Gray);
                if (!string.IsNullOrEmpty(e)) Log(e, Color.Red);

                if (p.ExitCode != 0)
                {
                    Log("PowerShell partitioning failed (exit code: " + p.ExitCode + ").", Color.Red);
                    if (e.Contains("MI_RESULT_NOT_FOUND") || e.Contains("not recognized"))
                    {
                        Log("  Storage module not available (requires Windows 8/Server 2012+).", Color.Yellow);
                    }
                    return false;
                }

                Log("Partitioning succeeded via PowerShell.", Color.Green);
                return true;
            }
            catch (Exception ex) { Log("PowerShell error: " + ex.Message, Color.Red); return false; }
            finally { try { File.Delete(tmp); } catch { } }
        }

        // Returns "gpt", "mbr", "raw" or null if it cannot be determined. Used to
        // tell a genuine partitioning failure apart from diskpart complaining that
        // the disk is already in the style we asked for.
        static string GetDiskStyle(int diskNum)
        {
            try
            {
                Process p = new Process();
                p.StartInfo.FileName = "powershell.exe";
                p.StartInfo.Arguments = "-NoLogo -NoProfile -ExecutionPolicy Bypass -Command "
                    + "\"(Get-Disk -Number " + diskNum + ").PartitionStyle\"";
                p.StartInfo.UseShellExecute = false;
                p.StartInfo.RedirectStandardOutput = true;
                p.StartInfo.RedirectStandardError = true;
                p.StartInfo.CreateNoWindow = true;
                p.Start();
                string o = p.StandardOutput.ReadToEnd();
                p.StandardError.ReadToEnd();
                p.WaitForExit();
                o = (o ?? "").Trim();
                return o.Length == 0 ? null : o;
            }
            catch { return null; }
        }

        bool RunDiskpartDirect()
        {
            string script = "select disk " + _diskNum + "\r\n" +
                            "rescan\r\n" +
                            "clean\r\n" +
                            "convert " + (UseGpt ? "gpt" : "mbr") + "\r\n" +
                            "rescan\r\n";

            if (_rbSingle.Checked)
                script += "create partition primary\r\nformat fs=exFAT quick override label=\"OpenCode AI\"\r\nassign\r\nexit\r\n";
            else
            {
                int sz;
                if (_rbTwo.Checked)
                {
                    var info = _cmbUsb.SelectedItem as UsbInfo;
                    sz = info != null ? Math.Max(10, (int)(info.SizeGB / 2)) : 37;
                }
                else sz = (int)_nudSize.Value;
                string l1 = _rbTwo.Checked ? "OpenCode AI" : _txtLabel1.Text;
                string l2 = _rbTwo.Checked ? "Storage" : _txtLabel2.Text;
                script += "create partition primary size=" + (sz * 1024) + "\r\nformat fs=exFAT quick override label=\"" + l1 + "\"\r\nassign\r\n";
                script += "create partition primary\r\nformat fs=exFAT quick override label=\"" + l2 + "\"\r\nassign\r\nexit\r\n";
            }

            string tmp = Path.GetTempFileName() + ".txt";
            File.WriteAllText(tmp, script, Encoding.ASCII);
            try
            {
                Log("Running diskpart (fallback)...", Color.Gray);
                Log("  Script: " + tmp, Color.DarkGray);
                SetStat("Partitioning via diskpart...");
                SetProg(12);

                Process p = new Process();
                p.StartInfo.FileName = "diskpart.exe";
                p.StartInfo.Arguments = "/s \"" + tmp + "\"";
                p.StartInfo.UseShellExecute = false;
                p.StartInfo.RedirectStandardOutput = true;
                p.StartInfo.RedirectStandardError = true;
                p.StartInfo.CreateNoWindow = true;
                p.Start();
                string o = p.StandardOutput.ReadToEnd();
                string e = p.StandardError.ReadToEnd();
                p.WaitForExit();

                Log(o, Color.Gray);
                if (!string.IsNullOrEmpty(e)) Log(e, Color.Red);

                if (o.Contains("DiskPart has encountered an error") || o.Contains("failed") || o.Contains("no volumes"))
                {
                    Log("diskpart reported errors in output.", Color.Red);
                    Log("Possible fixes:", Color.Yellow);
                    Log("  1. Close all Explorer/file manager windows showing the USB", Color.Yellow);
                    Log("  2. Check the drive isn't write-protected", Color.Yellow);
                    Log("  3. Make sure you're running as Administrator", Color.Yellow);
                    Log("", Color.Gray);
                    Log("Diskpart output often reports 'DiskPart has encountered an error' even", Color.Gray);
                    Log("when some commands succeeded. Check the actual output above.", Color.Gray);
                    return false;
                }

                Log("Partitioning succeeded via diskpart.", Color.Green);
                return true;
            }
            catch (Exception ex) { Log("diskpart error: " + ex.Message, Color.Red); Fail("diskpart error: " + ex.Message); return false; }
            finally { try { File.Delete(tmp); } catch { } }
        }

        string FindOcVolume()
        {
            try
            {
                using (ManagementObjectSearcher s = new ManagementObjectSearcher("SELECT * FROM Win32_LogicalDisk WHERE DriveType=2"))
                {
                    foreach (ManagementObject v in s.Get())
                    {
                        if ((v["VolumeName"] as string) == "OpenCode AI")
                        {
                            string id = v["DeviceID"] as string;
                            if (id != null)
                            {
                                using (ManagementObjectSearcher ls = new ManagementObjectSearcher(
                                    "ASSOCIATORS OF {Win32_LogicalDisk.DeviceID='" + id + "'} WHERE AssocClass=Win32_LogicalDiskToPartition"))
                                {
                                    foreach (ManagementObject l in ls.Get())
                                    {
                                        if (l["Antecedent"] != null && l["Antecedent"].ToString().Contains("Disk #" + _diskNum))
                                        {
                                            return id;
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            catch { }
            return null;
        }

        string FindStorage(string exclude)
        {
            try
            {
                using (ManagementObjectSearcher s = new ManagementObjectSearcher("SELECT * FROM Win32_LogicalDisk WHERE DriveType=2"))
                {
                    foreach (ManagementObject v in s.Get())
                    {
                        string id = v["DeviceID"] as string;
                        // Compare normalised: callers now pass an exclude ending in
                        // "\", whereas DeviceID is a bare "E:". Without this the
                        // tools volume would not be excluded and could be reported
                        // as the storage volume.
                        if (id != null && !NormRoot(id).Equals(NormRoot(exclude), StringComparison.OrdinalIgnoreCase))
                        {
                            using (ManagementObjectSearcher ls = new ManagementObjectSearcher(
                                "ASSOCIATORS OF {Win32_LogicalDisk.DeviceID='" + id + "'} WHERE AssocClass=Win32_LogicalDiskToPartition"))
                            {
                                foreach (ManagementObject l in ls.Get())
                                {
                                    if (l["Antecedent"] != null && l["Antecedent"].ToString().Contains("Disk #" + _diskNum))
                                    {
                                        return id;
                                    }
                                }
                            }
                        }
                    }
                }
            }
            catch { }
            return null;
        }

        string FindVolume()
        {
            try
            {
                using (ManagementObjectSearcher s = new ManagementObjectSearcher(
                    "ASSOCIATORS OF {Win32_DiskDrive.DeviceID='\\\\.\\PHYSICALDRIVE" + _diskNum + "'} WHERE AssocClass=Win32_DiskDriveToDiskPartition"))
                {
                    foreach (ManagementObject p in s.Get())
                    {
                        using (ManagementObjectSearcher ls = new ManagementObjectSearcher(
                            "ASSOCIATORS OF {Win32_DiskPartition.DeviceID='" + p["DeviceID"] + "'} WHERE AssocClass=Win32_LogicalDiskToPartition"))
                        {
                            foreach (ManagementObject l in ls.Get())
                            {
                                string id = l["DeviceID"] as string;
                                if (id != null && Directory.Exists(id)) return id;
                            }
                        }
                    }
                }
            }
            catch { }

            try
            {
                using (ManagementObjectSearcher s = new ManagementObjectSearcher("SELECT * FROM Win32_LogicalDisk WHERE DriveType=2"))
                {
                    foreach (ManagementObject v in s.Get())
                    {
                        string id = v["DeviceID"] as string;
                        if (id != null && Directory.Exists(id))
                        {
                            using (ManagementObjectSearcher ls = new ManagementObjectSearcher(
                                "ASSOCIATORS OF {Win32_LogicalDisk.DeviceID='" + id + "'} WHERE AssocClass=Win32_LogicalDiskToPartition"))
                            {
                                foreach (ManagementObject l in ls.Get())
                                {
                                    if (l["Antecedent"] != null && l["Antecedent"].ToString().Contains("Disk #" + _diskNum))
                                    {
                                        return id;
                                    }
                                }
                            }
                        }
                    }
                }
            }
            catch { }

            foreach (DriveInfo d in DriveInfo.GetDrives())
                if (d.DriveType == DriveType.Removable && d.IsReady) return d.RootDirectory.FullName;
            return null;
        }

        void Configure(string root)
        {
            // Extract launcher.exe as "OpenCode AI.exe" - the visible, double-click entry point.
            // A .exe resolves its own folder at runtime (Assembly.Location), so it keeps working
            // no matter what drive letter Windows assigns the stick on a given PC. A .lnk shortcut
            // instead bakes in an absolute "D:\..." path at creation time, which breaks the moment
            // the same USB stick mounts under a different letter on another computer.
            string exePath = Path.Combine(root, "OpenCode AI.exe");
            try
            {
                using (Stream lx = Assembly.GetExecutingAssembly().GetManifestResourceStream("launcher.exe"))
                {
                    if (lx != null)
                    {
                        using (FileStream fs = new FileStream(exePath, FileMode.Create, FileAccess.Write))
                        {
                            lx.CopyTo(fs);
                        }
                        Log("Extracted: OpenCode AI.exe", Color.Green);
                    }
                }
            }
            catch (Exception ex) { Log("Launcher extract error: " + ex.Message, Color.Red); }

            // Remove stale artifacts from older versions of this tool (previous runs on this stick)
            foreach (string old in new[] { "OpenCode AI Launcher.exe", "OpenCode AI.lnk", "Session Logs.lnk", "Check for Updates.lnk", "launcher.vbs" })
            {
                string p = Path.Combine(root, old);
                try { if (File.Exists(p)) File.Delete(p); } catch { }
            }

            foreach (string h in new[] { "bin", "config", "data", "nodejs", "wezterm", "sessions", "launcher.bat", "launcher-no-wezterm.bat", "opencode-usb-creator.ico" })
            {
                string p = Path.Combine(root, h);
                try { if (File.Exists(p) || Directory.Exists(p)) File.SetAttributes(p, FileAttributes.Hidden); } catch { }
            }
            foreach (string v in new[] { "README.txt", "OpenCode AI.exe", "Session Logs.bat", "Check for Updates.bat" })
            {
                string p = Path.Combine(root, v);
                try
                {
                    if (File.Exists(p)) { var a = File.GetAttributes(p); if ((a & FileAttributes.Hidden) == FileAttributes.Hidden) File.SetAttributes(p, a & ~FileAttributes.Hidden); }
                }
                catch { }
            }

            // Session Logs / Check for Updates: self-locating batch files (via %~dp0) instead of
            // .lnk shortcuts, so these also survive a drive-letter change on another PC.
            try
            {
                File.WriteAllText(Path.Combine(root, "Session Logs.bat"),
                    "@echo off\r\nstart \"\" explorer.exe \"%~dp0sessions\"\r\n");
                Log("Created: Session Logs.bat", Color.Green);
            }
            catch (Exception ex) { Log("Session Logs.bat error: " + ex.Message, Color.Red); }

            try
            {
                File.WriteAllText(Path.Combine(root, "Check for Updates.bat"),
                    "@echo off\r\ncd /d \"%~dp0bin\"\r\npowershell.exe -NoLogo -ExecutionPolicy Bypass -NoProfile -File \"%~dp0bin\\check-updates.ps1\"\r\npause\r\n");
                Log("Created: Check for Updates.bat", Color.Green);
            }
            catch (Exception ex) { Log("Check for Updates.bat error: " + ex.Message, Color.Red); }

            string sess = Path.Combine(root, "sessions");
            if (!Directory.Exists(sess)) { Directory.CreateDirectory(sess); try { File.SetAttributes(sess, FileAttributes.Hidden); } catch { } }
        }

        void ConfigFile(string root)
        {
            string cp = Path.Combine(root, "data", "config", "opencode.json");
            if (File.Exists(cp))
            {
                try { Log("Config: " + cp, Color.Green); }
                catch (Exception ex) { Log("Config error: " + ex.Message, Color.Yellow); }
            }
        }
    }
}
