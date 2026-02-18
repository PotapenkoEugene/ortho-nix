# ortho-nix

```
 ██████╗ ██████╗ ████████╗██╗  ██╗ ██████╗
██╔═══██╗██╔══██╗╚══██╔══╝██║  ██║██╔═══██╗
██║   ██║██████╔╝   ██║   ████████║██║   ██║
██║   ██║██╔══██╗   ██║   ██╔══██║██║   ██║
╚██████╔╝██║  ██║   ██║   ██║  ██║╚██████╔╝
 ╚═════╝ ╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝ ╚═════╝

    /\_/\
   ( o.o )  ~ home-manager switch ~
    > ^ <
   /|   |\
  (_|   |_)
```

Nix Home Manager configuration for my work/life system. Bioinformatics by day, config tweaking by night.

## Quick Start

```bash
# The only command you need to remember
home-manager switch

# The command you'll run after breaking something
home-manager switch
```

## Project Structure

```
.
├── flake.nix                  # Dependency wiring (don't touch unless brave)
├── flake.lock                 # Pinned versions (touch even less)
├── home.nix                   # Main entrypoint — imports everything
├── scripts/
│   └── obsidian_daily_notes.lua   # Daily note generator with task sync
├── sounds/
│   ├── peon/                      # Orc Peon voice lines (original)
│   └── peasant/                   # Human Peasant voice lines (active)
├── claude-code/
│   ├── settings.json          # Claude Code hooks & permissions
│   ├── statusline.sh          # Custom status line with git indicators
│   └── skills/                # Custom slash commands
│       ├── hm-switch/         # Safe home-manager rebuild workflow
│       ├── process-transcript/ # Convert whisper transcripts to notes
│       └── note/              # Add insights to Obsidian projects
└── modules/
    ├── gnome.nix              # GNOME extensions & dconf
    ├── theme.nix              # QT + GTK theming
    ├── shell.nix              # Bash, fzf, aliases
    ├── music.nix              # mpd + rmpc
    ├── tmux.nix               # Tmux (prefix: Ctrl+A)
    ├── terminal.nix           # Kitty + nixGL
    ├── packages.nix           # All the packages
    ├── claude-code.nix        # Claude Code integration
    └── neovim/
        ├── default.nix        # Neovim entrypoint
        ├── options.nix        # Editor settings & globals
        ├── plugins.nix        # LSP, treesitter, AI, notebooks...
        ├── keymaps.nix        # All keybindings
        └── lua.nix            # Extra Lua config
```

## The Stack

| Layer | Tool | Vibe |
|-------|------|------|
| Desktop | GNOME + Tiling Shell | i use tiling btw |
| Theme | Orchis-Dark + Papirus | dark mode is not a preference, it's a lifestyle |
| Terminal | Kitty | fast + GPU-accelerated + images in terminal |
| Multiplexer | Tmux (Ctrl+A) | sessions survive reboots thanks to resurrect |
| Editor | Neovim (nixvim) | TokyoNight colorscheme, because Tokyo never sleeps |
| Shell | Bash + vi mode | hjkl everywhere, no escape (well, jk actually) |
| AI | Copilot + CodeCompanion + Claude Code | OpenAI for chat, Claude for agentic coding |
| Notebooks | Molten + Jupytext | Jupyter in Neovim, as nature intended |
| Notes | Obsidian | daily notes with bidirectional project sync |
| Music | mpd + rmpc | lo-fi beats to bioinformatics to |
| Files | Oil.nvim + Dolphin | one for terminal, one for normie moments |
| Speech-to-text | whisper.cpp (tiny model) | because typing is so 2023 |
| Analytics | datamash + tabiew (`tw`) | awesome colorful viewer for xlsx, tsv, csv and other table formats — with SQL-like querying |
| Weather | wego + OpenWeatherMap | because alt-tabbing to a browser is too slow |
| Containers | ctop | Docker monitoring without leaving tmux |
| Translation | vim-translator + Google | hover-translate words and sentences without leaving Neovim |
| Documents | pandoc + pdftk + zathura | convert, merge, and read anything |

## Claude Code Integration

Claude Code is integrated with custom statusline, skills, and notification hooks.

### Status Line

A powerline-style status bar showing real-time session info:

```
ortho │ ~/config/home-manager │  main ✓ │ Opus 4.6 │ [INSERT] │ ▆ 94k/200k │ ⟳0
```

**Features:**
- Git status indicators: `✓` (clean) `✗` (dirty) `●` (staged) `…` (untracked)
- Context window usage as actual token count (e.g. `94k/200k`) with color: gray → yellow (>50%) → red (>75%)
- Compaction counter `⟳N` with color gradient: green (0-1) → yellow (2) → red (3+)
- Vim mode display when active
- Current agent tracking

### Custom Skills (Slash Commands)

- **`/hm-switch`** - Safe home-manager rebuild workflow
  - Formats with alejandra
  - Tests with `home-manager build`
  - Applies with `home-manager switch`
  - Shows git diff

- **`/process-transcript`** - Convert whisper transcripts to structured notes
  - Processes from `~/Orthidian/transcripts/`
  - Extracts summary, key points, action items
  - Saves to `~/Orthidian/processed-transcripts/`

- **`/note`** - Add insights from conversation to Obsidian projects
  - Intelligently adds subtasks/comments to existing objectives
  - Avoids redundancy with semantic duplicate detection
  - Never creates top-level tasks (archive-safe)
  - Interactive project and objective selection

### Notification Hooks

Desktop notifications with Warcraft III Human Peasant voice lines:
- **General attention** - Random `PeasantWhat{1-4}.wav` — "Yes, milord?" / "What is it?"
- **Success** - Random `PeasantYes{1-4}.wav` — "Right-o" / "Off I go, then!"
- **Build complete** - `PeasantReady1.wav` or `PeasantYes3.wav` — "Ready to work" / "All right"
- **Errors** - `PeasantAngry4.wav` or `PeasantYesAttack4.wav` — "A horse kicked me once" / "That's it. I'm dead."

Sound playback uses PipeWire (`pw-play`) with voice lines from `sounds/peasant/`.

### Permission Presets

Auto-allowed: `alejandra`, `home-manager build`, `home-manager switch`, `git status/diff`
Requires confirmation: `git push`, `git commit`

## Tmux Keymaps

Prefix = `Ctrl+A`

| Keys | What it does |
|------|-------------|
| **Popups** | |
| `prefix + t` | btop (system monitor) |
| `prefix + d` | ctop (container monitor) |
| `prefix + g` | lazygit (git TUI) |
| `prefix + n` | today's daily note (nvim, jumps to Work todos) |
| `prefix + u` | duf (disk usage) |
| `prefix + w` | wego (weather via OpenWeatherMap) |
| `prefix + m` | rmpc (music player) |
| `prefix + p` | floax (floating pane) |
| `prefix + o` | sessionx (session picker) |
| `prefix + y` | Migal VPN popup |
| `prefix + C-y` | AWS VPN connect |
| `prefix + R` | Reload tmux config |
| **Navigation** | |
| `prefix + h/j/k/l` | Select pane (left/down/up/right) |
| `prefix + H/L` | Previous/next window |
| `prefix + s/v` | Split horizontal/vertical |
| `prefix + z` | Zoom pane |
| `prefix + c` | Kill pane |
| `prefix + S` | Choose session |

## Neovim Keymaps Cheatsheet

Leader = `Space`

| Keys | What it does |
|------|-------------|
| `jk` | Escape (insert mode) |
| `<leader><leader>` | Toggle previous buffer |
| `<leader>y` | Copy to system clipboard |
| **Telescope** | |
| `<leader>ff` | Find files |
| `<leader>fg` | Live grep |
| `<leader>fb` | Buffers |
| `<leader>fh` | Help tags |
| **AI** | |
| `<leader>aa` | CodeCompanion actions |
| `<leader>ac` | CodeCompanion chat |
| **Notebooks** | |
| `<leader>ml` | Execute line |
| `<leader>mc` | Execute chunk |
| `<leader>ma` | Execute all |
| `<leader>mn/mp` | Next/prev chunk |
| `<leader>mh/ms` | Hide/show output |
| **Translation** | |
| `<leader>tw` | Translate word under cursor (popup) |
| `<leader>ts` | Translate sentence (popup) |
| **Obsidian** | |
| `<leader>on` | New note |
| `<leader>od` | Generate daily note |

## Obsidian Daily Notes

`<leader>od` generates a daily note that syncs tasks bidirectionally with project files.

### How It Works

Each morning, the script reads yesterday's note and:

1. **Work Objectives** - Carries over, marks done if corresponding todo was completed/resolved
2. **Work Todos** - Syncs subtasks to `projects/` files, imports fresh undone subtasks from project
3. **Personal Todos** - Two modes:
   - **With `[[link]]`**: Full project sync to `personal/` dir (same as work)
   - **Without `[[link]]`**: Simple carry-forward with emoji aging

### Task Markers

| Marker | Meaning | Behavior |
|--------|---------|----------|
| `[ ]` | Todo | Carries forward, gets emoji |
| `[!]` | Urgent | Carries forward, gets emoji |
| `[>]` | Deferred | Carries forward, gets emoji |
| `[x]` | Completed | Filtered out from daily, synced to project |
| `[~]` | Decided not to do | Same as `[x]` — filtered out, synced to project |

### Auto-Create

If a task links to `[[new-project]]` but no file exists, a full project template is created automatically in the appropriate directory (`projects/` or `personal/`).

### Directories

- `~/Orthidian/projects/` - Work project files (archives)
- `~/Orthidian/personal/` - Personal project files (archives)
- `~/Orthidian/daily/` - Daily notes (YYYY-MM-DD.md)

## Hotkeys (Because Mouse is Lava)

| Key | What happens | Why you'll love it |
|-----|-------------|-------------------|
| `F8` | Toggle whisper-stream 🎤 | Talk to your computer like a sci-fi movie character. First press = start recording, second press = stop & save to `~/Orthidian/transcripts/`. Perfect for meetings when you're too lazy to type (or pretending to pay attention). |
| `Ctrl+F5` | Brightness → 0 | Instant stealth mode. Your screen becomes a black hole. |
| `Alt+T` | Launch Kitty | Terminal faster than you can say "sudo" |
| `Alt+D` | Launch Dolphin | File manager goes *click click* |

### Whisper Commands (For When F8 Isn't Enough)

```bash
# The "did I just say that?" test
~/test-whisper-mic.sh          # Record 5 seconds, transcribe immediately

# Transcribe that embarrassing voice memo
whisper -f /path/to/audio.wav

# Check what nonsense you've been dictating
ls ~/Orthidian/transcripts/
```

**Fun fact:** After fighting with whisper for 6 hours and spawning 400+ processes that almost nuked the system, we discovered the magic `-f` flag that just... writes to a file. Sometimes the best solutions are the simplest ones. 🤦

---

*Powered by Nix, fueled by coffee, maintained by mass `home-manager switch` runs.*
