<img width="1254" height="1254" alt="OpenCode AI Portable USB" src="https://raw.githubusercontent.com/dapperdan17/OC-Ai-Portable-USB/main/src/splash.png" />


# OpenCode AI - Portable USB Creator

Turn any USB 3.0 stick (16GB+) into a **self-contained AI coding assistant** that runs on any
Windows 10/11 PC. No installation. No admin rights on the target machine. Nothing
left behind on the computer you plug it into.

> **USB 2.0 works but is slow.** USB 3.0 (blue port) is recommended -- OpenCode and
> WezTerm load noticeably faster. Avoid cheap no-name sticks if you can; they tend
> to fail mid-write and corrupt the drive.

`Ai Portable USB creator.exe` partitions and formats a USB stick, then unpacks a fully
portable copy of [OpenCode](https://opencode.ai) -- a terminal AI coding agent --
together with its own bundled terminal (WezTerm) and JavaScript runtime (Node.js).
Everything runs from the stick.

**The only self-contained .exe USB creator with automatic partitioning and first-run
API key popup for OpenCode.** No `git clone`. No `npm install`. No internet needed
until your first API call.

---

## Download & use

1. Download **`Ai Portable USB creator.exe`** from the
   [Releases](../../releases) page.
2. Right-click it > **Run as administrator**.
3. Pick your USB stick, choose a partition style (**MBR** is the most compatible),
   and click through.
4. When it finishes, eject the stick.
5. Plug it into any Windows 10/11 PC, open it in File Explorer, and double-click
   **`OpenCode AI.exe`**.

> **Why administrator?** The creator needs to partition and format your USB drive.
> Windows reserves low-level disk operations (partition tables, file systems, volume
> labels) for administrators. Without it, the tool can see your USB but cannot write
> to it. This only applies to the machine that *creates* the stick -- the machines
> that *run* OpenCode need no special permissions.

> **First run:** Windows SmartScreen may warn about an unsigned app
> ("Windows protected your PC"). Click **More info > Run anyway**. This is expected
> for any app that isn't code-signed -- it isn't a sign of malware, but don't take
> that on faith: the full source is in [`src/`](src/) so you can build it yourself.

---

## What you get on the stick

| Component | Purpose |
|-----------|---------|
| **OpenCode** v1.18.3 | Terminal AI coding agent |
| **WezTerm** | GPU-accelerated portable terminal |
| **Node.js** v26.5.0 | Bundled JavaScript runtime |
| **ripgrep** | Fast search (bundled, no download needed) |
| **API key popup** | First-run provider selection with GUI |
| **Key protection** | Read-only config + hidden backup + auto-restore |

---

## First-time setup

When you launch `OpenCode AI.exe` for the first time, a popup appears:

1. **Select your AI provider** from the dropdown (OpenCode Zen, Anthropic, OpenAI, Google, or Other)
2. **Click the link** to sign up / get your API key (opens in your default browser)
3. **Paste your API key** in the input box
4. **Click OK** to save and launch OpenCode

**Recommended:** [OpenCode Zen](https://opencode.ai/auth) -- built-in, free tier
available, and the simplest option to get started.

The USB can be created offline (no internet needed to build the stick), but
**using OpenCode requires an API key and an internet connection** to talk to
the AI provider. The popup only appears once. Your API key is saved to the
USB drive and protected:
- Config file is set to **read-only** to prevent accidental deletion
- A **hidden backup** is created automatically
- If the config is deleted, the key is **restored from backup** on next launch

---

## Stays on the stick, not the host

This is the whole point of the project. Credentials, session history, cache, logs and
temp files are all redirected onto the USB drive -- the app writes **nothing** into the
host user's profile. Verified by snapshotting the host's temp/AppData folders, running
the stick, and diffing: zero new application files.

**One honest limit:** Windows *itself* records that a USB device was connected (in the
registry and Event Log), no matter what any app does. That's outside this project's
control. What's guaranteed is that *your* files, keys and conversations never touch the
host's disk -- not that the machine has no idea a stick was plugged in.

---

## Works on any drive letter

USB sticks get whatever drive letter Windows hands out, and it changes from PC to PC.
Everything on the stick locates itself at runtime, so it works whether it mounts as
`D:`, `E:`, or anything else -- including a fully self-contained `PATH` so it uses the
stick's own Node.js and OpenCode rather than anything installed on the host.

---

## How it compares

Other portable AI USB projects exist, but they all require `git clone`, `npm install`,
or running scripts with prerequisites. This project is different:

| Feature | This project | Others |
|---------|-------------|--------|
| **Setup method** | Single .exe, double-click | `git clone` + `npm install` + scripts |
| **USB partitioning** | Automatic (MBR/GPT, single/dual) | Manual or none |
| **First-run experience** | GUI popup with provider links | Command-line prompts |
| **API key protection** | Read-only + backup + auto-restore | Plain text file |
| **Internet for setup** | Not needed | Required (download runtimes) |
| **Terminal** | WezTerm (GPU-accelerated) | Standard terminal or web UI |

---

### Why this exists

I'm not a coder. I have no qualifications. I have ideas and, apparently,
enough patience to not give up -- don't tell anyone.

I tried other portable AI USB installers and none worked for me. I'd get
stuck, give up, and go back to Googling. Then I started using AI to
*build* instead of just *ask*.

It hasn't been smooth. I broke things constantly because I didn't
understand the tools. I'd say "allow" when the model was about to delete
something. I started with ChatGPT copy and paste for two months before I
even realised I could ask it to generate files. I learned by messing
things up and fixing them -- YouTube, Google, asking AI itself how to use
AI.

When I found OpenCode and started using AI in a terminal, that was the
real step forward. Every feature here came from me saying "what if it did
this?" and the AI saying "here's how." Sometimes I had to push back --
some models flat out said things couldn't be done because of
restrictions, but a different model or a different approach found a way.
It broke a lot along the way, but we got there.

**AI doesn't replace the skill of coding.** But it gives people with
ideas a way to execute them. If you have curiosity and something you want
to build, that's enough to start.

### Who this is for

- **Engineers and designers** who want AI assistance on site without
  installing software on client machines
- **Office workers** on locked-down corporate PCs where you can't install
  anything
- **People on the road** who work from different computers and want their
  environment to travel with them
- **Anyone helping others** who aren't computer-savvy -- hand them the
  USB, they double-click, it works

---

## Building it yourself

The [`src/`](src/) folder contains the full source:

- `create-usb.cs` -- the installer (C#/WinForms)
- `launcher.cs` -- the tiny self-locating launcher that becomes `OpenCode AI.exe`
- `build-embedded.ps1` -- zips the payload and compiles the installer
- `create-usb.ps1` -- legacy PowerShell-based creator (fallback)
- `check-updates.ps1` -- the update-check script the installer writes onto the stick
- icons and splash image

Building also needs the **payload** -- the actual OpenCode, Node.js and WezTerm binaries
that get embedded into the `.exe`. Those are large third-party downloads and are **not**
included in this repository (see [Licenses](#licenses)). Grab them from:

- OpenCode: <https://opencode.ai>
- Node.js (Windows x64): <https://nodejs.org>
- WezTerm: <https://wezterm.org>
- ripgrep: <https://github.com/BurntSushi/ripgrep/releases>

Arrange them into a folder matching the layout the installer expects
(`bin\`, `nodejs\`, `wezterm\`, `config\`, `data\`), then run:

```powershell
.\build-embedded.ps1 -SourcePath "<payload folder>"
```

---

## Troubleshooting

If something goes wrong:

1. **Run `Diagnose.bat`** on the USB drive -- it checks system compatibility and
   reports what's wrong
2. **Review the diagnostic report** before sharing it -- it may contain file paths
   or system details you'd rather keep private. Remove anything sensitive.
3. **Check [existing issues](../../issues)** before creating a new one -- your
   problem may already have a fix
4. **[Open a new issue](../../issues/new)** if nothing matches -- include the
   diagnostic output and what you were doing when it broke

---

## Requirements

- Windows 10/11, 64-bit
- A USB stick (all data on it will be erased)
- Administrator rights **on the machine that creates the stick** (not on machines that run it)
- Internet only if you use a cloud AI provider

---

## Licenses

This project's own code (the installer and launcher) is released under the
[MIT License](LICENSE).

It bundles and redistributes third-party software, each under its own license --
OpenCode, Node.js, WezTerm and ripgrep. Those binaries were downloaded from their
official sources when the .exe was built, then embedded into it. You don't need
internet to create the USB -- everything is already inside the .exe. See
[LICENSE](LICENSE) for attribution and links.
