{
  config,
  pkgs,
  lib,
  ...
}: {
  home.packages =
    (with pkgs; [
      # System monitoring
      htop
      btop

      # Analytics
      datamash
      tabiew
      xan # CSV Swiss Army knife

      # Music clients — daemon only on Linux (music module disabled on darwin)
      yt-dlp
      ffmpeg

      # File management
      ripgrep # Often used with fzf
      fd # Modern find alternative, works well with fzf
      television # Fuzzy finder TUI (tv command)
      eza # color alternative for ls
      bat # cat with syntax highlight

      # Documents / office
      aria2
      pandoc
      mermaid-cli # diagram generation from text
      wego # terminal weather
      ctop # container top

      # Browser automation
      playwright-cli # Playwright CLI for browser automation in Claude Code
      notebooklm-py # NotebookLM CLI — programmatic access via undocumented RPC API

      # Dev tools
      cmatrix
      git
      lazygit
      obsidian
      nil # Nix LSP
      bash-language-server
      alejandra # nix formatter
      shfmt # shell formatter
      shellcheck # shell linter
      imagemagick
      pkg-config

      # Python environment
      (python313.withPackages (ps:
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

      # Desktop / communication
      kitty-themes

      # Fonts
      jetbrains-mono
      nerd-fonts.symbols-only

      # Node.js
      nodejs_24
      pnpm

      # Bioinformatics
      sratoolkit
      bwa
      minimap2
      seqkit
      multiqc
      samtools
      bcftools
      bedtools
      fastqc
      bowtie2
      macs2

      # Build tools
      cmake
      gcc

      # Package managers / envs
      micromamba
      uv # Python package manager (provides uvx)

      # Utilities
      dos2unix
      tldr
      tree
      presenterm # terminal presentations in markdown

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
    ++ lib.optionals pkgs.stdenv.isLinux (with pkgs; [
      # Linux-only: GUI office / viewers / desktop apps
      libreoffice
      zathura # PDF viewer (GTK)
      pdftk # PDF toolkit (meta.platforms = linux)
      telegram-desktop
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
      # Other Linux-only
      bwa-mem2 # x86_64-only SIMD (SSE/AVX), not available on aarch64
      blast # x86_64-only (meta.platforms excludes aarch64-darwin)
      gws # Google Workspace CLI — undefined in nixpkgs for aarch64-darwin
      fuse # for installing apps from AppImage
      yad # GTK dialogs (used for REC indicator in whisper-stream)
    ]);
}
