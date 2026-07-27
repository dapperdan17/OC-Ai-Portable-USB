# FAQ - Hacker News / Reddit / GitHub

Copy-paste answers when people ask questions. Keep replies short and honest.

---

## Hacker News Post

**Title (under 80 chars):**
```
Show HN: OpenCode AI Portable USB – single .exe that creates a portable AI coding USB
```

**URL:**
```
https://github.com/dapperdan17/OC-Ai-Portable-USB
```

**Opening comment (post immediately after submitting):**
```
I built a single self-contained .exe that turns any USB stick into a portable OpenCode AI coding environment.

What it does:
- Partitions and formats a USB drive (MBR/GPT, single or dual partitions)
- Bundles OpenCode + Node.js + WezTerm + ripgrep – all embedded in the .exe
- First-run GUI popup for API key setup (OpenCode Zen, Anthropic, OpenAI, Google)
- Everything runs from the stick – zero files written to the host PC

Why it exists:
I'm not a coder. I tried other portable AI USB projects and none worked for me. I started using AI to build instead of just ask, and ended up with this.

The whole thing is C# / WinForms, compiled with .NET Framework 4.0's csc.exe. No npm, no git clone, no prerequisites. The .exe extracts everything to the USB on first run.

Tested on locked-down work PCs where I can't install anything – works as long as the machine can see the USB drive.

Honest limitations:
- Windows only (10/11, 64-bit)
- Requires admin on the machine that creates the stick (not on machines that run it)
- API key required for cloud AI providers
- Unsigned exe – SmartScreen will warn. Full source is in src/ so you can build it yourself.

Source: https://github.com/dapperdan17/OC-Ai-Portable-USB
Release: https://github.com/dapperdan17/OC-Ai-Portable-USB/releases/tag/v1.0.0
```

---

## HN FAQ Answers

**Q: Why not just use `git clone` and `npm install`?**
A: That's what every other portable AI USB project requires. This is for people who can't do that — locked-down work PCs, no git installed, no npm, no admin rights. Double-click the exe, pick your USB, done.

**Q: How is this different from code-stick?**
A: code-stick requires git clone + npm install and uses Ollama (local models). This is a single .exe with automatic USB partitioning, a GUI API key popup, and uses cloud providers. Different approach entirely.

**Q: Why not use Electron or Tauri?**
A: Because .NET Framework 4.0 ships with every Windows 10/11 install. Zero prerequisites. An Electron app would be 200MB+ of JavaScript runtime alone.

**Q: Is this just wrapping OpenCode?**
A: Yes, in the same way a Linux distro wraps the Linux kernel. It bundles OpenCode + Node.js + WezTerm + ripgrep, partitions the USB, redirects all state to the stick via XDG env vars, adds a GUI API key popup, and ensures zero host footprint. The value is the packaging and the portability guarantees.

**Q: What about code signing?**
A: I don't have a code signing certificate. The full source is in `src/` — you can build it yourself and verify what it does. That's more transparent than a signed binary you can't inspect.

**Q: Does it work on Mac/Linux?**
A: No, Windows only. The partitioning uses diskpart/PowerShell Storage cmdlets, the launcher is C#/WinForms, and OpenCode itself is the Windows build.

**Q: Why C# / WinForms?**
A: Because it compiles with the .NET Framework 4.0 csc.exe that ships with Windows. No SDK, no NuGet, no build tools needed. Anyone can rebuild it with `build-embedded.ps1`.

**Q: How does the API key protection work?**
A: It's accident prevention, not security. Config file is set read-only, backup is hidden + read-only, and the launcher auto-restores from backup if the config is deleted. Any process running as the user can still modify it — it's not encryption.

**Q: Does it leave traces on the host PC?**
A: No application files. All XDG paths, TEMP, and config redirect to the USB. Verified by snapshotting host temp/AppData before and after running. Windows itself records that a USB was plugged in (registry, Event Log) — that's outside the app's control.

**Q: Does it work offline?**
A: Creating the USB works offline. Using OpenCode requires internet — it's a cloud AI client. The API key popup only appears once.

**Q: How do you update it?**
A: Replace `bin\opencode.exe` on the USB with the latest release from opencode.ai. There's a `Check for Updates.bat` on the stick that checks for new versions.

**Q: Why 212MB?**
A: That's the cost of self-contained: OpenCode (~50MB) + Node.js (~60MB) + WezTerm (~80MB) + ripgrep (~5MB) + the zip compression. It's all embedded in the exe so no internet is needed to create the stick.

**Q: What's the license?**
A: MIT for the installer and launcher code. The bundled binaries (OpenCode, Node.js, WezTerm, ripgrep) are each under their own licenses. See LICENSE in the repo.

**Q: Can I use it with Ollama / local models?**
A: No. This wraps OpenCode which is a cloud AI client. For local models, look at code-stick or llamafile.

**Q: Have you tested on actual locked-down PCs?**
A: Yes. Works on corporate machines where you can't install anything. The exe runs from the USB, no admin needed on the target machine.

**Q: What if I don't have admin to create the USB?**
A: You need admin on the machine that creates the stick (diskpart requires it). You don't need admin on machines that run it.

**Q: How do I get an API key?**
A: The popup on first launch has links to each provider's key page. Recommended: OpenCode Zen (opencode.ai/auth) — free tier, simplest option.

**Q: I'm not a coder. How did you build this?**
A: Used AI (ChatGPT, then OpenCode) to write the C# code. Started with copy-paste, learned by breaking things and fixing them. The README has the full story.

---

## Quick Short Replies

- **"Just use git clone"** → "That's what everyone else does. This is for people who can't — no git, no npm, no admin on the target machine."

- **"Not code signed"** → "No cert. Full source in src/ so you can verify and build yourself. More transparent than a signed binary you can't inspect."

- **"Windows only?"** → "Yes. OpenCode itself supports other platforms, but the USB creator uses diskpart + .NET Framework. The stick runs on any Windows 10/11 PC."

- **"Why not Electron?"** → ".NET Framework 4.0 ships with Windows. Zero prerequisites. Electron would double the size."

- **"Cool but I don't use OpenCode"** → "Fair. This is specifically for OpenCode users who want a portable setup. Not trying to be everything."

- **"Can you add Linux/Mac support?"** → "Not with this approach — diskpart and WinForms are Windows-only. A different tool would be needed."

---

## Reddit Post (r/selfhosted)

**Title:** I built a single .exe that creates a portable OpenCode AI USB stick

**Body:**
```
I've been working on this for a while. It's a single self-contained .exe that:

1. Partitions and formats a USB drive (MBR/GPT, single or dual partitions)
2. Bundles OpenCode + Node.js + WezTerm + ripgrep — all embedded in the .exe
3. Adds a first-run GUI popup for API key setup
4. Everything runs from the stick — zero files written to the host PC

No git clone. No npm install. No prerequisites. Double-click the exe, pick your USB, done.

I'm not a coder — I built this using AI (ChatGPT copy-paste, then OpenCode). The whole thing is C# / WinForms compiled with .NET Framework 4.0's csc.exe.

Tested on locked-down work PCs where I can't install anything. Works as long as the machine can see the USB drive.

Source: https://github.com/dapperdan17/OC-Ai-Portable-USB
Release: https://github.com/dapperdan17/OC-Ai-Portable-USB/releases/tag/v1.0.0

Happy to answer questions. The full source is in src/ if you want to verify what it does.
```

---

## Reddit Post (r/opencode)

**Title:** Portable USB Creator for OpenCode — single .exe, zero host footprint

**Body:**
```
Built a tool that creates a fully portable OpenCode USB stick from a single .exe.

What it does:
- Partitions/formats USB (MBR/GPT, single/dual partitions)
- Bundles OpenCode + Node.js + WezTerm + ripgrep
- First-run GUI popup for API key setup (Zen, Anthropic, OpenAI, Google)
- All state redirects to USB via XDG env vars — zero host files modified

No git clone, no npm, no prerequisites. Just double-click the exe.

Source: https://github.com/dapperdan17/OC-Ai-Portable-USB
Release: https://github.com/dapperdan17/OC-Ai-Portable-USB/releases/tag/v1.0.0
```

---

## GitHub Issue Template (for OC-Ai-Portable-USB repo)

When people open issues, ask for:
1. Windows version (10/11, build number)
2. USB stick make/model/size
3. Whether they created the stick or are running from it
4. Antivirus software installed
5. Diagnostic report from Diagnose.bat

---

## Twitter/X Post

```
Built a single .exe that turns any USB stick into a portable AI coding environment.

No git clone. No npm. No prerequisites. Double-click, pick your USB, done.

OpenCode + Node.js + WezTerm + ripgrep — all embedded.

I'm not a coder. Built this with AI.

github.com/dapperdan17/OC-Ai-Portable-USB
```
