{
  config,
  pkgs,
  lib,
  ...
}: {
  home.packages =
    [
      # Tmux session picker — delivered via Nix so it's on PATH on all hosts
      # (mac's ~/.config/home-manager is a stale snapshot; path-based refs break there)
      (pkgs.writeShellScriptBin "tmux-recency-source"
        (builtins.readFile ../scripts/tmux-recency-source.sh))
    ]
    ++ (with pkgs; [
      # ── Core CLI tools — installed on ALL hosts (desktop + headless server) ──

      # System monitoring
      htop
      btop

      # Analytics / data
      datamash
      tabiew
      xan # CSV Swiss Army knife

      # File management / search
      ripgrep # used with fzf
      fd # modern find, works well with fzf
      television # fuzzy finder TUI (tv command)
      eza # color ls alternative
      bat # cat with syntax highlight

      # Documents
      pandoc

      # Dev tools — core
      git
      gh # GitHub CLI
      lazygit
      nil # Nix LSP
      bash-language-server
      alejandra # nix formatter
      shfmt # shell formatter
      shellcheck # shell linter

      # Node.js (needed for Claude Code plugins: caveman, understand-anything)
      nodejs_24
      pnpm

      # Utilities
      dos2unix
      tldr
      tree
      presenterm # terminal presentations in markdown
    ])
    ++ [
      # Python environment — available on all hosts (needed for molten/quarto/jupytext on server too)
      (pkgs.python313.withPackages (ps:
        with ps; [
          weasyprint # for presenterm rendering
          openpyxl
          pandas
          ipykernel
          jupyter-client
          jupytext
          pynvim
          matplotlib
          numpy
          # molten.nvim dependencies:
          pnglatex
          plotly
          kaleido
          pyperclip
          mutagen # required for rmpc
          pip
          fpdf
          pypdf
          python-docx
          scipy
          geopandas
          shapely
          rasterio
          fiona
          requests
          playwright # for excalidraw-diagram render script
        ]))
    ]
    ++ lib.optionals (!config.ortho.headless) (with pkgs; [
      # ── Heavy / desktop / GUI packages — skipped on headless server ──

      # Multimedia
      yt-dlp
      ffmpeg

      # Documents / office
      aria2
      texliveFull # Complete TeX Live distribution
      mermaid-cli # diagram generation from text
      wego # terminal weather (needs API key)
      ctop # container top
      cmatrix

      # Browser automation
      playwright-cli # Playwright CLI for browser automation in Claude Code
      notebooklm-py # NotebookLM CLI

      # Dev tools — heavy
      obsidian # GUI note app
      imagemagick
      pkg-config
      cmake
      gcc

      # Desktop / communication / automation
      kitty-themes
      tdl # Telegram CLI

      # Fonts
      jetbrains-mono
      nerd-fonts.symbols-only

      # Package managers / envs
      micromamba
      uv # Python package manager (provides uvx)

      # GIS
      gdal

      # R
      (rWrapper.override {
        packages = with rPackages; [
          tidyverse
          gt
          ggpubr
          svglite
          data_table
          IRkernel
          ggplot2
          dplyr
        ];
      })
    ])
    ++ lib.optionals pkgs.stdenv.isDarwin (with pkgs; [
      # claude-code installed via native installer (~/.local/bin/claude) for auto-updates
    ])
    ++ lib.optionals (pkgs.stdenv.isLinux && !config.ortho.headless) (with pkgs; [
      # Linux-only: GUI office / viewers / desktop apps
      libreoffice
      zathura # PDF viewer (GTK)
      pdftk # PDF toolkit (meta.platforms = linux)
      telegram-desktop
      firefox
      witr # "why is this running?" (reads /proc, Linux only)
      # Music daemon (managed by music module, disabled on darwin)
      mpd
      mpc
      # Linux-only: network tools, clipboard, GUI desktop stacks, hardware tools
      nettools # ifconfig etc.
      xclip
      wl-clipboard
      brightnessctl
      openfortivpn
      dconf-editor
      dconf2nix
      kdePackages.dolphin
      kdePackages.konsole # terminal in dolphin
      pipewire # multimedia in dolphin
      libcanberra-gtk3 # missing dependency for dolphin
      egl-wayland # X11 kitty support
      # Bioinformatics GUIs (darwin builds broken/absent in nixpkgs)
      igv
      qgis
      kent # UCSC Kent utilities (bedGraphToBigWig, etc.)
      # Bioinformatics (all Linux — aarch64-darwin builds too patchy)
      sratoolkit
      bwa
      bwa-mem2 # x86_64-only SIMD
      blast # x86_64-only
      minimap2
      seqkit
      multiqc
      samtools
      bcftools
      bedtools
      fastqc
      fastp
      bowtie2
      macs2
      # Other Linux-only
      autossh # auto-restart SSH connections (mac tab sleep/wake reconnect)
      fuse # for installing apps from AppImage
      yad # GTK dialogs (used for REC indicator in whisper-stream)
    ]);
}
