local wezterm = require("wezterm")
local config = wezterm.config_builder()

-- WezTerm rebuilds the environment for programs it spawns and resets TEMP/TMP
-- back to the host default, even when the parent process had them redirected.
-- Measured effect: opencode extracts a ~500KB native addon into the host's
-- %LOCALAPPDATA%\Temp on every launch, leaving a trace on the machine. The XDG
-- vars set by launcher.bat DO survive, so only TEMP/TMP need restoring here.
--
-- NOTE on WezTerm's OWN blob lease file: launcher.bat sets TEMP/TMP (lines
-- 59-60) BEFORE WezTerm is launched (line 93), so WezTerm inherits the
-- redirected TEMP. WezTerm's blob lease file should therefore go to the USB's
-- data\tmp directory. If it still appears in the host's %LOCALAPPDATA%\Temp,
-- that would indicate WezTerm hardcodes that path internally -- which would be
-- an unfixable limitation (WezTerm has no config option for its own state or
-- temp directory; config.set_environment_variables only affects child processes).
--
-- The USB root is derived from this file's own path rather than hardcoded, so
-- it keeps working whatever drive letter the stick is assigned.
local cfg_path = wezterm.config_file                            -- <root>\config\wezterm.lua
local cfg_dir  = cfg_path:match("^(.*)[\\/][^\\/]*$") or ""     -- <root>\config
local usb_root = cfg_dir:match("^(.*)[\\/][^\\/]*$") or ""      -- <root>
local usb_tmp  = usb_root .. "\\data\\tmp"

-- wezterm also replaces PATH with the HOST's PATH, discarding the one
-- launcher.bat set up. Measured inside a wezterm pane: the USB's bin/ and
-- nodejs/ were absent, while the host's Program Files\nodejs and
-- AppData\Roaming\npm were present. That means opencode resolved node, npm and
-- friends from whatever the host machine happened to have installed - so the
-- stick appeared to work on a developer PC and failed on a clean one.
-- Prepending the USB directories makes the stick use its own bundled runtimes
-- first. The host PATH is kept on the end so system tools still resolve.
local host_path = os.getenv("PATH") or ""
local usb_path  = usb_root .. "\\bin;"
               .. usb_root .. "\\nodejs;"
               .. usb_root .. "\\wezterm;"
               .. host_path

config.set_environment_variables = {
  TEMP = usb_tmp,
  TMP  = usb_tmp,
  PATH = usb_path,
  -- Node resolves bundled modules from the stick, never the host profile
  NODE_PATH = usb_root .. "\\nodejs\\node_modules",
}

config.font_size = 11.0
config.font = wezterm.font("Cascadia Code")
config.line_height = 1.15
config.window_background_opacity = 0.95
config.macos_window_background_blur = 20
config.color_scheme = "Catppuccin Mocha"
config.hide_tab_bar_if_only_one_tab = true
config.default_cursor_style = "BlinkingBlock"
-- TITLE is required for a draggable title bar. "RESIZE" alone gives resize
-- borders but no title bar, leaving the window impossible to move by mouse.
config.window_decorations = "TITLE | RESIZE"
config.window_padding = { left = 4, right = 4, top = 4, bottom = 4 }
config.audible_bell = "Disabled"
config.keys = {
  {
    key = "n",
    mods = "CTRL|SHIFT",
    action = wezterm.action.SpawnWindow,
  },
}

config.default_domain = "local"

return config
