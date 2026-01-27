# ortho-nix

```
    ┌──────────────────────────────────────────┐
    │  $ home-manager switch                   │
    │                                          │
    │  ██████╗ ██████╗ ████████╗██╗  ██╗ ██████╗  │
    │  ██╔═══╝ ██╔══██╗╚══██╔══╝██║  ██║██╔═══██╗ │
    │  ██║     ██████╔╝   ██║   ████████║██║   ██║ │
    │  ██║     ██╔══██╗   ██║   ██╔══██║██║   ██║ │
    │  ╚██████╗██║  ██║   ██║   ██║  ██║╚██████╔╝ │
    │   ╚═════╝╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝ ╚═════╝ │
    │                                          │
    │  "It works on my machine"                │
    │  -- because my machine IS the config     │
    └──────────────────────────────────────────┘
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
└── modules/
    ├── gnome.nix              # GNOME extensions & dconf
    ├── theme.nix              # QT + GTK theming
    ├── shell.nix              # Bash, fzf, aliases
    ├── music.nix              # mpd + rmpc
    ├── tmux.nix               # Tmux (prefix: Ctrl+A)
    ├── terminal.nix           # Kitty + nixGL
    ├── packages.nix           # All the packages
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
| AI | Copilot + CodeCompanion | OpenAI for chat, Claude for agent mode |
| Notebooks | Molten + Jupytext | Jupyter in Neovim, as nature intended |
| Notes | Obsidian | daily notes with auto task sync magic |
| Music | mpd + rmpc | lo-fi beats to bioinformatics to |
| Files | Oil.nvim + Dolphin | one for terminal, one for normie moments |

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

## Secrets

API keys live in `~/.secrets/env` (sourced by bash). Never in the repo. Never.

```
~/.secrets/
└── env          # chmod 600, exports OPENAI_API_KEY & CLAUDE_CODE_OAUTH_TOKEN
```

## Bioinformatics Tools

Because someone has to align those reads:

| Tool | Purpose |
|------|---------|
| samtools | BAM/SAM wrangling |
| bcftools | VCF/BCF operations |
| bedtools | Genomic intervals |
| multiqc | QC report aggregation |
| igv | Genome browser |
| Python 3.12 | pandas, numpy, matplotlib, jupyter... |

## Daily Notes Workflow

The `obsidian_daily_notes.lua` script (`<leader>od`) does something unreasonably sophisticated:

```
Yesterday's Note                    Today's Note
┌─────────────────┐     ┌─────────────────┐
│ [x] Done task   │     │                 │
│ [ ] Undone task │────>│ [ ] Undone task  │  (carried over + day counter)
│ [ ] Work [[proj]]│────>│ [ ] Work [[proj]]│  (synced with project file)
│ New info...     │────>│ New info...      │
└─────────────────┘     └─────────────────┘
                              │
                              v
                        projects/proj.md  (bidirectional sync)
```

---

*Powered by Nix, fueled by coffee, maintained by mass `home-manager switch` runs.*
