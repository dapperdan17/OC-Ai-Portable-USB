<img width="1254" height="1254" alt="7bf66f2c-a3a5-4b4b-8c78-0f019bf0d339" src="https://github.com/user-attachments/assets/169ccf33-e416-488f-9d7a-6ea41b8f8329" />


# OpenCode AI - Portable USB Creator

Turn any USB stick into a **self-contained AI coding assistant** that runs on any
Windows 10/11 PC. No installation. No admin rights on the target machine. Nothing
left behind on the computer you plug it into.

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

The popup only appears once. Your API key is saved to the USB drive and protected:
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

## Why this exists

I'm not a coder. I have no qualifications in programming. I don't fully
understand every line of code in this project.

What I do have is ideas, imagination, and the patience to ask questions.

A coder understands *why* that code is there, *where* to put it, and *how*
to make it work together. I don't have that. What I have is the vision: I
know what I want the thing to *do*. I can describe it, test it, break it,
and say "that's not right, what if it worked like this instead?" AI takes
that and turns it into code.

This project started because I tried other portable AI USB installers and
none of them worked for me. I'd get stuck, give up, and go back to
Googling things manually. Then I started using AI to *build* instead of
just *ask*. I'd describe what I wanted, and the AI would explain things in
a way that made sense -- not dumbing it down, just meeting me where I am.

Every feature in here -- the popup, the key protection, the auto-restore --
came from me saying "what if it did this?" and the AI saying "here's how."
AI wrote most of the code. I directed it, tested it, and asked it to fix
it when it broke.

I have another app I've been working on for a year and a half. I keep
pottering with it, making mistakes, over-wording things, asking too much
in one go. I dream it could be the road to working for myself. It may
work. It does work. But I don't fully understand the topic it's built
for -- I just want to learn, and I want to make it usable for everybody,
even people with no knowledge of that area. If it gets even a few more
people interested in something they didn't know about before, that's
enough.

**AI doesn't replace the skill of coding.** People who studied for years
to become engineers understand things I never will. But AI gives people
with ideas a way to *execute* those ideas. It turns "what if" into
"here's how." And if you have curiosity, patience, and something you want
to build -- that's enough to start.

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
OpenCode, Node.js, WezTerm and ripgrep. Those binaries are **not** in this repository;
they're downloaded from their official sources at build time and embedded into the
released `.exe`. See [LICENSE](LICENSE) for attribution and links.
