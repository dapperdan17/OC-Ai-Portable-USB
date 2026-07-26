=============================================
  Portable OpenCode AI USB
  Version 1.18.3
=============================================

SELF-CONTAINED AI CODING ASSISTANT
Works on any Windows 10/11 PC. No installation needed.
All data stays on this USB drive. Zero traces on host PC.

FIRST-TIME SETUP:
  1. Plug this USB into any Windows PC
  2. Double-click "OpenCode AI.exe"
  3. A popup will appear - select your AI provider
  4. Get an API key from the provider's website (use your phone)
  5. Paste the API key and click Save
  6. OpenCode launches automatically
  7. Popup only appears on first use (key is saved to USB)

HOW TO USE (after setup):
  1. Plug this USB into any Windows PC
  2. Double-click "OpenCode AI.exe"
  3. OpenCode starts in a terminal window
  4. When you exit, your session is saved

WHAT'S INCLUDED:
  - OpenCode v1.18.3 (terminal AI coding agent)
  - Node.js v26.5.0 portable runtime
  - WezTerm portable terminal (GPU-accelerated)
  - Ripgrep (fast file search)
  - API key popup with provider selection
  - All data stays on this USB drive

SUPPORTED AI PROVIDERS:
  - OpenCode Zen (recommended, built-in)
  - Anthropic (Claude)
  - OpenAI (GPT)
  - Google Gemini

REQUIREMENTS:
  - Windows 10/11 (64-bit)
  - USB 3.0 port (recommended)
  - Internet connection for cloud AI providers

DRIVE LAYOUT (varies by USB size):
  Tools partition: OpenCode program and tools
  Storage partition: your projects and files

  Drive letters are assigned automatically by Windows.
  Look for the "OpenCode AI" volume label to identify the drive.

DATA STORAGE:
  API Key:       data\config\opencode.json
  Sessions:      data\xdg\data\opencode\opencode.db
  Temp files:    data\tmp\
  Config:        data\config\

DO'S:
  DO - Use this USB on any Windows PC
  DO - Keep the USB plugged in while using OpenCode
  DO - Store your projects on the USB drive
  DO - Use the popup to configure your API key
  DO - Keep the USB safe - it contains your API key

DON'TS:
  DON'T - Install any software on the host PC
  DON'T - Copy files from the USB to the host PC
  DON'T - Edit opencode.json manually (use the popup)
  DON'T - Delete data\config\apikey.backup (it protects your key)
  DON'T - Remove the USB while OpenCode is running
  DON'T - Share your API key with others

TROUBLESHOOTING:
  - If popup appears again: Your API key was deleted.
    Re-enter it using the popup.
  - If OpenCode won't start: Try a different USB port.
  - If session is slow: Use a USB 3.0 port (blue).
  - Run "Diagnose.bat" to check system compatibility.

=============================================
