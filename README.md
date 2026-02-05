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
| Terminal | Kitty (via nixGL) | fast + GPU-accelerated + images in terminal |
| Multiplexer | Tmux (Ctrl+A) | sessions survive reboots thanks to resurrect |
| Editor | Neovim (nixvim) | TokyoNight colorscheme, because Tokyo never sleeps |
| Shell | Bash + vi mode | hjkl everywhere, no escape (well, jk actually) |
| AI | Copilot + CodeCompanion + Claude Code | OpenAI for chat, Claude for agentic coding |
| Notebooks | Molten + Jupytext | Jupyter in Neovim, as nature intended |
| Notes | Obsidian | daily notes with auto task sync magic |
| Music | mpd + rmpc | lo-fi beats to bioinformatics to |
| Files | Oil.nvim + Dolphin | one for terminal, one for normie moments |
| Speech-to-text | whisper.cpp (tiny model) | because typing is so 2023 |

## Claude Code Integration

Claude Code is integrated with custom statusline, skills, and notification hooks.

### Status Line

A powerline-style status bar showing real-time session info:

```
ortho │ ~/config/home-manager │  main ✓ │ Sonnet 4.5 │ [INSERT] │ ▆ 76%
```

**Features:**
- Git status indicators: `✓` (clean) `✗` (dirty) `●` (staged) `…` (untracked)
- Color-coded context usage: gray (plenty) → yellow (medium) → red (low)
- Vim mode display when active
- Current agent tracking
- Smart bar graph for context (▂▄▆)

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

Desktop notifications with sound alerts for:
- **General attention** - Plays message-new-instant.oga when Claude needs attention
- **Success** - Plays complete.oga after successful `home-manager switch`
- **Build complete** - Notification after `home-manager build` finishes
- **Errors** - Plays dialog-error.oga when commands fail

Sound playback uses PipeWire (`pw-play`) with system sounds from `/usr/share/sounds/freedesktop/stereo/`.

### Permission Presets

Auto-allowed: `alejandra`, `home-manager build`, `git status/diff`
Requires confirmation: `home-manager switch`, `git push`, `git commit`

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
| **Obsidian** | |
| `<leader>on` | New note |
| `<leader>od` | Generate daily note |

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
