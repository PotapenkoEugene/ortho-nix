# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Active Obsidian Project
- Project: Desktop
- File: ~/Orthidian/projects/Desktop.md

## What This Is

A Nix Flake-based Home Manager configuration for user `ortho`. Two hosts:
- **`ortho`** — x86_64-linux (non-NixOS, Ubuntu-based with Nix). Full desktop config: GNOME, PipeWire, whisper hotkey, local LLM, peon sounds.
- **`ortho-mac`** — aarch64-darwin (Apple Silicon Mac Studio). nix-darwin with home-manager as a submodule. Single activation: `darwin-rebuild switch --flake .#ortho-mac`. Shared tooling only: shell, neovim, tmux, kitty, Claude Code, bioinformatics CLIs, Obsidian workflow.

**Disabled on darwin:** `gnome`, `theme`, `music` (mpd), `piper`, `llm`, `obsidian-backup`, `kitty-session` modules; whisper F8 hotkey; VPN popups; Peon notifications/sounds; all systemd timers.

## Mac Studio — Working Conventions

**SSH hostname:** `mac-studio` (Tailscale, 100.68.68.16). All mac tasks must be done via `ssh mac-studio` — never ask the user to run commands manually unless truly interactive.

**Project directory:** Always use `~/Projects/` for code repos on mac (e.g. `~/Projects/TGbotMessageToHebrew`). **Never use `~/Documents/`, `~/Desktop/`, or `~/Library/`** — those are iCloud Drive folders. iCloud causes `open(2)` to hang for launchd agents, background scripts, and any process started before the user's full GUI session is authenticated. Plain dirs directly under `~` (like `~/Projects/`) are always local, always fast.

**darwin-rebuild:** Mac uses the flake from GitHub, not a local clone:
```bash
sudo darwin-rebuild switch --flake 'github:PotapenkoEugene/ortho-nix#ortho-mac' --refresh
```

## Mac Studio Bootstrap

First-time setup on the Mac Studio (run on the mac, not this machine):

```bash
# 1. Install Nix (DetSys — enables flakes by default)
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
exec $SHELL -l
nix --version  # verify

# 2. Clone this config + Obsidian vault
mkdir -p ~/.config && git clone git@github.com:PotapenkoEugene/ortho-nix.git ~/.config/home-manager
git clone <orthidian-remote> ~/Orthidian

# 3. Stage all files (flake only sees git-tracked files; commit not required)
cd ~/.config/home-manager && git add -A

# 4. First activation — bootstraps nix-darwin + home-manager in one shot
nix run nix-darwin/master#darwin-rebuild -- switch --flake .#ortho-mac

# 5. Ongoing activation (darwin-rebuild now in PATH)
darwin-rebuild switch --flake .#ortho-mac

# 6. Post-activation checks
which bash kitty tmux tv nvim claude          # /nix/store or /run/current-system/sw/bin
# Tmux: open kitty, start tmux, copy something — verify pbcopy works
cat ~/.claude/settings.json | jq '.hooks'     # should have only SessionStart inject entry
samtools --version && bcftools --version       # bioinf tools present
```

Copy `~/.secrets/env` from this machine to the mac out-of-band (scp / 1Password).

## What This Is (detail)

## Key Commands

```bash
# Apply configuration changes
home-manager switch

# Build without applying (test configuration)
home-manager build

# Update all flake inputs (nixpkgs, home-manager, nixvim)
nix flake update

# Format Nix files
alejandra .

# Check dconf settings (useful for debugging GNOME config)
dconf dump /org/gnome/
```

## Architecture

**Flake inputs**: `nixpkgs` (unstable), `home-manager`, `nixvim` - all following nixpkgs. The nixvim module is loaded as a Home Manager module in `flake.nix`.

**Modular structure** - `home.nix` is a cross-platform base; per-host files in `hosts/` add Linux-only or darwin-only modules + username/homeDir:

```
flake.nix                   # mkHome helper, 2 homeConfigurations (ortho + ortho-mac)
home.nix                    # Cross-platform base (shared imports, guarded activations)
hosts/
  ortho-linux.nix           # Linux-only imports + home.{username,homeDirectory} + genericLinux+nixGL
  ortho-mac.nix             # darwin home.{username,homeDirectory} only
modules/
  gnome.nix                 # GNOME extensions + dconf settings  [Linux only]
  theme.nix                 # QT + GTK themes  [Linux only]
  shell.nix                 # Bash, fzf, sessionPath  [shared, guarded]
  music.nix                 # rmpc + mpd  [Linux only]
  tmux.nix                  # Tmux config (prefix Ctrl+A)  [shared, guarded]
  terminal.nix              # Kitty terminal config  [shared, guarded]
  packages.nix              # home.packages list  [shared, Linux-only sublist]
  claude-code.nix           # Claude Code settings, skills, hooks  [shared, guarded]
  piper.nix                 # Piper TTS + voice models  [Linux only]
  llm.nix                   # llama-cpp-vulkan + Qwen2.5-3B model  [Linux only]
  obsidian-backup.nix       # systemd timer — git push Orthidian  [Linux only]
  kitty-session.nix         # systemd timer — snapshot kitty tabs  [Linux only]
  ollama.nix                # Ollama LLM daemon + model pulls  [darwin only]
  secrets.nix               # sops-nix: age-encrypted secrets → /run/secrets/  [darwin, no-op until secrets/mac.yaml committed]
  tgbot.nix                 # Telegram→Hebrew bot: launchd agent + tgbot-run + tgbot-update  [darwin, no-op until secrets/mac.yaml committed]
  neovim/
    default.nix             # Neovim entrypoint
    options.nix             # colorscheme, opts, globals
    plugins.nix             # All plugin configs
    keymaps.nix             # All keymaps
    lua.nix                 # extraConfigLua block
scripts/
  obsidian_daily_notes.lua  # Daily note dashboard generator (~320 lines)
  whisper-stream-toggle.sh  # F8 hotkey script
  vpn-migal-popup.sh        # Migal VPN tmux popup wrapper
sounds/
  peon/                     # Warcraft III Peon voice lines for notifications
claude-code/
  settings.json             # Claude Code hooks & permissions
  statusline.sh             # Powerline-style status bar script
  skills/                   # Custom Claude Code skills
    hm-switch/              # Safe home-manager rebuild workflow
    process-transcript/     # Convert whisper transcripts to notes
    note/                   # Add insights to Obsidian project files
```

**`scripts/obsidian_daily_notes.lua`**: Called by tmux notes popup (`Ctrl+a n`), generates a read-only dashboard daily note:
- **3 sections**: Today, Meetings, Notes (simplified from 6)
- **Dashboard view**: No checkboxes (read-only view). Two lines per project: `- [[PROJECT]] N️⃣` + indented `    - top-level objective text`. Unlinked tasks: `- text N️⃣`
- **No sync-back**: Daily notes are read-only views. Task state changes happen in project files only (by Claude via `/note` or manually).
- Scans `projects/` and `personal/` for first undone top-level objective per file
- **Age tracking**: Keycap number emoji (1️⃣-9️⃣) = calendar days since current objective appeared
- Unlinked personal tasks carry forward from previous daily note (done filtered, age incremented)
- Projects with all objectives done are hidden from dashboard
- Done markers: `[x]`, `[X]` (completed), `[~]` (decided not to do) — used in project files only
- Undone markers: `[ ]`, `[!]`, `[>]` (blocked) — used in project files only, not shown in daily note
- Meetings and Notes sections carry forward if they have content
- **Project file format**: `## Objectives` + `## Notes` (optional: Summary, Related, Ideas if non-empty)

## Important Details

- **GPU support**: Uses `targets.genericLinux.enable = true` (home-manager built-in) for GPU driver access on non-NixOS. Replaced nixGL overlay which had `builtins.currentTime` incompatibility with Nix 2.28+.
- **GNOME keybindings**: Custom hotkeys (F8, Alt+T, etc.) defined in `modules/gnome.nix` via dconf settings under `org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/`
- **Desktop activation**: `home.nix` includes activation script (`copyDesktopFiles`) that symlinks `~/.nix-profile/share/applications` to `~/.local/share/applications/nix` for GNOME app menu integration
- **Neovim**: Leader key is Space; keymaps in `modules/neovim/keymaps.nix`
- **Shell vi-mode**: Bash uses `set -o vi` (configured in `modules/shell.nix`). `scripts/` dir is in `sessionPath`. `copyclip()` function provides OSC 52 clipboard integration.
- **Television (tv)**: Fuzzy finder TUI installed via nixpkgs. Shell integration via `eval "$(tv init bash)"` in `shell.nix`. Keybindings: **Ctrl+F** = path/file autocomplete (type a partial path first, e.g. `~/`), **Ctrl+H** = shell history search. Default Ctrl+T rebound to Ctrl+F (vi-mode owns Ctrl+R so history moved to Ctrl+H).
- **Formatters**: Nix uses `alejandra`, Bash uses `shfmt` (both installed in `modules/packages.nix`)
- **Python**: Packages declared via `python312.withPackages` in `modules/packages.nix` (includes jupyter, pandas, pynvim, etc.)
- **Bioinformatics**: samtools, bcftools, bedtools, fastqc, bowtie2, igv, macs2, multiqc installed via `modules/packages.nix`; `micromamba` available for Conda environments
- **Tmux copy mode**: `Ctrl+a Escape` enters copy mode (vi-mode: `/` to search, `v` to select, `y` to yank). Status bar turns red in copy mode.
- **Fuzzback**: `Ctrl+a f` opens fzf popup to fuzzy-search tmux scrollback history, jumps to matching line in copy mode
- **VPN popup**: `Ctrl+a y` opens Migal VPN in a tmux popup (`scripts/vpn-migal-popup.sh`). Uses separate tmux socket (`-L vpn`) so VPN persists after closing popup. Press `Escape` to close popup. `Ctrl+a Ctrl+y` for AWS VPN.
- **API keys**: Loaded from `~/.secrets/env` via environment variables (OPENAI_API_KEY, CLAUDE_CODE_OAUTH_TOKEN)
- **Session persistence principle**: tmux sessions are the user's primary workspace — automation must NEVER create bare sessions as a timeout fallback. `kitty-tab-launch.sh` waits up to 120s for resurrect restore to complete (detecting via the `last` symlink change), then only creates a new session if it genuinely wasn't in the snapshot. `save-kitty-session.sh` has a 3-minute boot cooldown (checks `/proc/uptime`) to prevent overwriting `session.conf` before restore completes.
- **Image rendering chain**: Kitty graphics protocol requires: `KITTY_DISABLE_WAYLAND=1` env var (in `home.nix`) + tmux `allow-passthrough on` (in `tmux.nix`) + image.nvim with Kitty backend and magick_rock (in `plugins.nix`)
- **CodeCompanion adapters**: Uses OpenAI for chat/inline strategies, `claude_code` for agent strategy (configured in `plugins.nix`)
- **Notes popup**: `Ctrl+a n` opens a persistent nvim session in `~/Orthidian/` via tmux popup (`scripts/notes-popup.sh`). Uses separate socket (`-L notes`) so the session persists across popup open/close. Auto-generates today's daily note on first open each day. Toggle with `Ctrl+a n`.
- **Codeburn popup**: `Ctrl+a T` opens codeburn TUI dashboard (AI token usage analytics) via `scripts/codeburn-popup.sh`. Launched via `npx -y codeburn` — first run downloads to `~/.npm/_npx/` cache; subsequent runs instant. Press `q` to quit.
- **Tmux alias fragility**: The tmux 3.5a workaround in `shell.nix` hardcodes a specific nix store path — breaks if that path is garbage-collected. Check with `ls /nix/store/msrldc9bfz6piaa0704m0djjm14mq151-tmux-3.5a/` if tmux stops working

## Whisper Speech-to-Text

Uses `whisper-cpp-vulkan` from nixpkgs (v1.8.3) with Intel Arc iGPU acceleration via Vulkan. Installed in `modules/packages.nix`. PipeWire echo cancellation removes system audio bleed from mic input.

**Hotkey:**
- **F8** - Toggle system audio + mic capture with speaker separation (start/stop)
  - First press: Start recording system audio (sink) + echo-cancelled microphone (source) via PipeWire
  - Second press: Stop → parallel transcription of both tracks → awk merges into `Other:`/`Me:` dialog

**Manual Usage:**
```bash
whisper -f audio.wav              # Transcribe audio file (uses medium.en)
```

**How F8 works:**
1. Press F8 → Auto-detects default sink + echo-cancelled mic source → two `pw-record` processes capture to separate `/tmp/` WAVs
2. Records both PIDs to `/tmp/whisper-stream.pid`, notifies with sink name + mic source type
3. Press F8 again → Kills pw-record → two `whisper-cli` processes transcribe both tracks **in parallel** (6 threads each) with timestamps
4. Raw output saved as `[System Audio]` + `[Mic]` sections in `~/Orthidian/transcripts/recording-YYYY-MM-DD-HHMM.txt`
5. Cleanup runs in background → awk parses timestamps, labels `Other:`/`Me:`, sorts chronologically, merges consecutive same-speaker lines → `recording-YYYY-MM-DD-HHMM-clean.txt`

**Echo cancellation:** PipeWire `module-echo-cancel` with WebRTC AEC algorithm. Config in `home.nix` → `~/.config/pipewire/pipewire.conf.d/echo-cancel.conf`. Creates a virtual source `echo-cancel-source` that subtracts system audio from mic in real-time. The script auto-detects this source, falls back to raw mic if unavailable.

**Technical details:**
- Model: Medium English (`~/whisper-models/ggml-medium.en.bin`, 1.5GB), falls back to small.en → tiny.en
- Model auto-downloaded on `home-manager switch` (configured in `modules/llm.nix`)
- Parallel transcription: both tracks transcribed simultaneously (6 threads each)
- Vulkan iGPU: uses Intel Arc (Meteor Lake) via Mesa ANV driver. GPU accessible via ACL on `/dev/dri/renderD128`
- Cleanup is pure awk (no LLM) — instant, deterministic, no hallucinations
- `notify-send` for desktop notifications

**Script location:** `scripts/whisper-stream-toggle.sh` (bound via dconf in `modules/gnome.nix:36-38`)

## Local LLM (Qwen2.5-3B)

Configured in `modules/llm.nix`. Provides `llama-cpp-vulkan` (llama-cli, llama-server, llama-bench) with Intel Arc iGPU acceleration via Vulkan. Auto-downloads the model on first `home-manager switch`.

**Model:** Qwen2.5-3B-Instruct Q4_K_M (~2.1GB) at `~/llm-models/qwen2.5-3b-instruct-q4_k_m.gguf`
**Speed:** iGPU via Vulkan (`-ngl 99`), ~15-25 tok/s expected. Falls back to CPU if GPU unavailable.

**Interactive chat:**
```bash
llm                    # alias — starts interactive conversation mode (iGPU accelerated)
```

**Transcript cleanup** (`scripts/clean-transcript.sh`):
Pure awk processing (no LLM needed):
1. Parses `[System Audio]` and `[Mic]` sections with timestamps
2. Labels lines as `Other:` / `Me:` based on source track
3. Sorts all lines chronologically by timestamp
4. Merges consecutive same-speaker lines into paragraphs
5. Strips noise markers (`[BLANK_AUDIO]`, `[Inaudible]`, etc.)

```bash
clean-transcript.sh <input-file> [output-file]    # standalone usage
# Automatically called by whisper-stream-toggle.sh on F8 stop (background)
```

Output: `recording-YYYY-MM-DD-HHMM-clean.txt` alongside the raw file (raw always preserved).

## TGbot Deployment (Mac Studio)

Telegram bot (`TGbotMessageToHebrew`) runs as `com.ortho.tgbot` launchd user agent on the mac, translating RU/EN↔Hebrew via local Ollama. Repo: `git@github.com:PotapenkoEugene/TGbotMessageToHebrew.git`.

- **Repo**: `~/Projects/TGbotMessageToHebrew` — manual clone + `uv sync --frozen`, not nix-managed. Must be outside iCloud Drive (`~/Documents/` forbidden — causes launchd hang).
- **Secrets**: `secrets/mac.yaml` (sops/age-encrypted in git). Age private key at `~/.config/sops/age/keys.txt` on the mac (out of repo, never commit).
- **Model**: `qwen3:32b` (already pulled by `modules/ollama.nix`).
- **DB**: `~/Library/Application Support/tgbot/tgbot.db`.
- **Logs**: `~/Library/Logs/tgbot.{log,err}`.
- **Modules**: `modules/secrets.nix` + `modules/tgbot.nix` — both are no-ops until `secrets/mac.yaml` is committed to git.

**Bootstrap (one-time on mac)**:
```bash
# Generate age key
nix shell nixpkgs#sops nixpkgs#age
mkdir -p ~/.config/sops/age && age-keygen -o ~/.config/sops/age/keys.txt && chmod 600 $_
age-keygen -y ~/.config/sops/age/keys.txt    # copy the age1… pubkey

# Fill it into .sops.yaml (replace AGE_PUBKEY_REPLACE_ME)
# Then create encrypted secrets:
SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt sops secrets/mac.yaml

# Clone bot repo + install deps (~/Projects = local, not iCloud)
mkdir -p ~/Projects && GIT_SSH_COMMAND='ssh -i ~/.ssh/id_github_ed25519 -o IdentitiesOnly=yes' git clone git@github.com:PotapenkoEugene/TGbotMessageToHebrew.git ~/Projects/TGbotMessageToHebrew
cd ~/Projects/TGbotMessageToHebrew && uv sync --frozen

# Commit secrets + apply
git add .sops.yaml secrets/mac.yaml && git commit -m "feat: add tgbot secrets" && git push
darwin-rebuild switch --flake .#ortho-mac
```

**Day-to-day**:
- Code update (after push from linux): `tgbot-update` on mac (pulls, syncs, restarts agent).
- Secret rotation: `SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt sops secrets/mac.yaml` → edit → save → git push → `/hm-switch`.
- See bootstrap guide: `secrets/README.md`.

## Claude Code Integration

Configuration tracked in `modules/claude-code.nix` and symlinked to `~/.claude/`.

**Custom Skills (Slash Commands):**

1. **`/hm-switch`** - Safe home-manager rebuild workflow
   - Runs `alejandra .` to format
   - Tests with `home-manager build`
   - Applies with `home-manager switch`
   - Shows git diff of changes

2. **`/process-transcript`** - Convert whisper transcripts to structured notes
   - Processes latest transcript from `~/Orthidian/transcripts/`
   - Extracts summary, key points, action items
   - Saves to `~/Orthidian/processed-transcripts/`
   - Usage: `/process-transcript` or `/process-transcript filename.txt`

3. **`/excalidraw-diagram`** - Generate Excalidraw diagrams as `.excalidraw` JSON + PNG
   - Creates visual argument diagrams (architectures, workflows, mental models)
   - Renders to PNG via `python3 ~/.claude/skills/excalidraw-diagram/references/render_excalidraw.py <file.excalidraw>`
   - First-time Chromium install: `python3 -m playwright install chromium`
   - View/edit `.excalidraw` files at https://excalidraw.com (drag-and-drop)
   - Output goes to the session's current working directory by default

4. **`/note`** - Manage Obsidian project tasks and add insights
   - **Quick-start**: `/note PROJECTNAME` — reads project file, shows objectives, suggests next task, saves project association to `.claude/CLAUDE.md`
   - **Interactive**: `/note` — lists all projects, lets you select one
   - **Autonomous tracking**: After `/note` sets project, Claude marks tasks `[x]` when completed and adds `- Done YYYY-MM-DD: description` notes
   - Adds new subtasks discovered during work
   - Checks for redundancy to avoid duplicates
   - Never creates top-level objectives, never deletes tasks
   - Preserves project file structure (archive mode)

**Notification Hooks (with Peon voice lines):**
Sound playback uses `pw-play` (PipeWire). Hooks defined in `claude-code/settings.json`:
- Notification (general): Desktop alert + random `PeonWhat{1-4}.wav` + **auto-popup** (see below)
- PostToolUse (home-manager switch): Desktop alert + random `PeonYes{1-4}.wav`
- PostToolUse (home-manager build): Desktop alert + random `PeonReady1.wav` or `PeonYes3.wav`
- PostToolUseFailure (home-manager *): Critical alert + `PeonAngry4.wav` or `PeonDeath.wav`

**Auto-Focus Popup (tmux):**
When Claude needs attention (permission prompt), a tmux popup appears in the **currently active tmux client** — no need to find the right Kitty tab.
- `scripts/claude-notify.sh` — hook handler: queues notifications, plays sound, opens popup
- `scripts/claude-popup.sh` — popup UI: captures last 25 lines of Claude's pane (with colors), forwards keypresses
- Press `y`/`n`/`a` directly in popup to approve/deny — popup auto-closes when Claude processes input
- Press `Escape` to close popup without responding (handle manually)
- Multiple notifications queued FIFO — after one popup closes, next opens
- Desktop `notify-send` always fires as backup (visible on other virtual desktops)

**Permission Presets:**
Global permissions in `claude-code/settings.json` (deployed to `~/.claude/settings.json`):
- **`defaultMode: acceptEdits`** — file Edit/Write operations auto-approved without per-session prompts
- **`additionalDirectories: ["~/Orthidian"]`** — write access to Obsidian vault from any project
- **Read** (bare) — read any file, any location, any extension
- **WebSearch / WebFetch** — web access globally allowed
- **~120 Bash allow rules** covering: core unix (grep, awk, sed, find, etc.), file ops (chmod, mkdir, cp, mv), languages (python3, Rscript, luajit, bash), nix toolchain, git (read ops + add/checkout/merge/rebase), bioinformatics (samtools, bcftools, bedtools, etc.), documents (pandoc, presenterm, magick), network (curl, wget), audio/media (ffmpeg, pw-play/record/cli, wpctl, pactl), whisper/LLM, docker, system info, tmux, desktop (dconf, gsettings, gnome-extensions), GIS (gdal*), GitHub CLI (gh)
- **Chained commands**: `alejandra . && home-manager build` and `alejandra . && home-manager build && home-manager switch` pre-approved for `/hm-switch` workflow
- **Requires confirmation:** `git push`, `git commit`
- **Intentionally excluded** (will prompt): `rm`, `sudo`, `pip install`, `npm install`, `kill`/`killall`

**Status Line:**
Custom status line displays: user@host | directory | git branch | model | vim mode | agent | context usage
- Script: `claude-code/statusline.sh` → `~/.claude/statusline.sh`
- Configuration in `settings.json` under `statusLine` key
- Shows colored, real-time session information

**Files:** Skills must be named `SKILL.md` (uppercase). Symlinks managed by `modules/claude-code.nix`.
- `claude-code/settings.json` → `~/.claude/settings.json`
- `claude-code/statusline.sh` → `~/.claude/statusline.sh`
- `claude-code/skills/*/SKILL.md` → `~/.claude/skills/*/SKILL.md`

## Adding New Features

### New GNOME Keybinding
1. Add custom keybinding block in `modules/gnome.nix`:
```nix
"org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/customN" = {
  name = "Description";
  command = "/path/to/script.sh";
  binding = "<Super>x";
};
```
2. Add path to `custom-keybindings` array
3. Run `home-manager switch`
4. Note: GNOME extensions require system restart, not just logout

### New Package
Add to `modules/packages.nix` under `home.packages = with pkgs;`

### New Shell Script
1. Create in `scripts/` directory
2. Make executable: `chmod +x scripts/name.sh`
3. Reference absolute path in keybindings or use `home.sessionPath`

## Troubleshooting

**GNOME extensions not loading:** Restart system (not just logout). Check `dconf read /org/gnome/shell/disable-user-extensions` is false.

**Kitty won't start:** Check `targets.genericLinux.enable` is set in `home.nix`. Verify GPU drivers are accessible.

**Whisper hotkey not working:** Verify F8 binding in GNOME settings. Check script has execute permissions. Test manually: `~/.config/home-manager/scripts/whisper-stream-toggle.sh`. If echo cancellation isn't working, check: `pw-cli ls Node | grep echo-cancel` — if missing, restart PipeWire: `systemctl --user restart pipewire pipewire-pulse`

**Home manager fails:** Check syntax with `alejandra .` then retry. Look for missing imports in `home.nix`.

**New files not found by `home-manager build`:** Nix flakes only copy git-tracked files into the Nix store. If you add new files (e.g., skill directories), run `git add <paths>` before `home-manager build` — no commit needed, just staging is enough.

**tmux "server exited unexpectedly" after home-manager switch:** The running tmux server was started with a different binary than the one now in PATH (version mismatch after switch). Fix: run `unalias tmux` in the current shell (stale aliases survive `source ~/.bashrc`), or open a fresh terminal. The server itself is fine — only the client-side alias is stale.

**git push denied to wrong GitHub account:** This repo (`PotapenkoEugene/ortho-nix`) must push via `id_github_ed25519`. The SSH agent may offer `hubnergit_ed25519` first (used for Hubner Lab), which gets accepted by GitHub but rejected for this repo. Fix is set per-repo and persists: `git config core.sshCommand 'ssh -i ~/.ssh/id_github_ed25519 -o IdentitiesOnly=yes'`. Never change `~/.ssh/config` for this — both accounts need to coexist.

## Flake Update Log

Track `nix flake update` runs here so breakage can be correlated with input changes.

| Date | nixpkgs | home-manager | nixvim | Reason |
|------|---------|--------------|--------|--------|
| 2026-03-10 | `9dcb002` (Mar 8) | `bb01474` (Mar 9) | `21ae25e` (Mar 1) | Added `gws` package (not in previous nixpkgs) |

## Future Improvements

Planned automation features to implement:

### 1. Google Workspace Integration (Calendar + Gmail)
- **Approach**: `gws` CLI v0.6.3 — [googleworkspace/cli](https://github.com/googleworkspace/cli) (Rust, in nixpkgs)
- **Auth**: OAuth 2.0 via Google Cloud Console project `booming-cairn-272721` (Desktop app client)
  - Client secret: `~/.config/gws/client_secret.json` (shared across accounts)
  - Per-account config dirs: `~/.config/gws/accounts/{selfisheugenes,potapgene}/`
  - Switch accounts via `GOOGLE_WORKSPACE_CLI_CONFIG_DIR` env var
  - Scopes: `gmail,calendar` (selfisheugenes also has `cloud-platform` for GCP console access)
- **Multi-account**: `--account` flag is broken for `+triage` skills in v0.6.3; use isolated config dirs instead
- **Token expiry**: Testing mode tokens expire after 7 days; re-auth with `gws auth login -s gmail,calendar` or publish consent screen for permanent tokens
- **Gmail**: `gws gmail +triage --query "after:X before:Y" --max 50` for inbox summary
- **Calendar**: `gws calendar +agenda --today` for upcoming events
- **Email digest**: `scripts/email-digest.sh` fetches via gws, passes to Claude for categorization only (Write tool only, prompt injection guard via EMAIL_DATA envelope)
- **Status**: Implemented — Gmail digest working, Calendar integration planned

### 2. Reminder Notifications
- Parse daily notes for:
  - Tasks with keycap age counters (1️⃣-9️⃣) — high-age items need attention
  - Meetings with times
- Send desktop notifications via `notify-send` or `dunst`
- Consider systemd user timers for periodic checks

### 3. Night Light
- Enable GNOME Night Light for automatic blue-light filter
- Schedule-based (e.g. sunset-to-sunrise or manual hours)
- dconf path: `org/gnome/settings-daemon/plugins/color`
- Settings: `night-light-enabled`, `night-light-temperature` (lower = warmer, default 2700), `night-light-schedule-automatic` (uses geolocation for sunset/sunrise)

### 5. Happy Coder (Mobile Claude Code Access)
- Repo: `https://github.com/slopus/happy` — mobile/web client for Claude Code sessions
- Install via `npm install -g happy-coder`
- Runs a persistent daemon that relays sessions through `api.cluster-fluster.com`
- **Security note**: The relay server can broker commands to your local machine — main risk is remote code execution, not code exposure. Consider self-hosting the server component (`happy-server`, Docker-based) to eliminate third-party relay trust.
- Bundled binaries (difft, rg) extracted without checksum verification
- Not yet installed — evaluate when mobile access is needed

### 6. Neovim Translation (Russian/English)
- Add in-editor translation for visual selections
- Top plugin candidates:
  - **pantran.nvim** (potamides) — modern interactive UI, motion-based, supports Google/DeepL/Yandex, no API key needed for Google. 326 stars, actively maintained.
  - **vim-translator** (voldikss) — mature, multiple engines (Google/Bing), floating window, visual select + replace. 533 stars.
  - **translate.nvim** (uga-rosa) — highly configurable, multiple output modes (float/replace/register). 204 stars.
- Recommended: **pantran.nvim** — best interactive UI, works with motions (`<leader>tris` for sentence), Google Translate works out of the box
- Config location: `modules/neovim/plugins.nix` (add plugin + keymap)
- Suggested keymaps: `<leader>tr` (translate selection), `<leader>tw` (translate word)

### 7. Obsidian Auto-Backup (Git)
- Systemd user timer + service to auto-commit and push `~/Orthidian/`
- Implementation: `systemd.user.services` + `systemd.user.timers` in Home Manager (~15 lines of Nix)
- Script: `git add -A && git commit -m "auto: $(date +%Y-%m-%d %H:%M)" && git push` (no-op if nothing changed)
- Frequency: configurable (every 30 min, hourly, or nightly)
- Prerequisites: Orthidian must be a git repo with a remote configured
- **Status**: Waiting — user plans to restructure the Obsidian repo first, implement after that's done

### 8. Git Hooks
- Pre-commit hooks for this config repo:
  - `alejandra` for Nix formatting
  - Lua syntax check for scripts
- Consider using `pre-commit` framework or nix-based hooks
- Add commit message templates for consistency
