{
  config,
  pkgs,
  lib,
  ...
}: {
  home.packages = with pkgs; [
    nettools # ifconfig and etc
    #system logs
    htop
    btop
    witr # "why is this running?" - process causality chain explorer
    # Analytics
    datamash
    tabiew
    xan # CSV Swiss Army knife
    # Music
    mpd
    mpc
    yt-dlp
    ffmpeg
    # Remote Connect
    #rustdesk
    #anydesk
    #nomachine-client
    # file managers
    ripgrep # Often used with fzf
    fd # Modern find alternative, works well with fzf
    television # Fuzzy finder TUI (tv command)
    eza # color alternative for ls
    bat # cat with syntax highlight
    # clipboard
    xclip
    wl-clipboard
    #Office
    aria2
    zathura
    libreoffice
    pdftk
    pandoc
    mermaid-cli # diagram generation from text
    wego # terminal weather
    ctop # container top
    playwright-cli # Playwright CLI for browser automation in Claude Code (token-efficient vs MCP)
    notebooklm-py # NotebookLM CLI — programmatic access via undocumented RPC API
    # playwright-mcp # (disabled — migrated to playwright-cli)
    brightnessctl
    cmatrix
    git
    lazygit
    obsidian # sudo chmod 4755 /nix/store/kqv91gd6jy83v2918bq1p90lzkir7y5n-electron-35.2.1/libexec/electron/chrome-sandbox
    ripgrep
    nil # Nix LSP
    bash-language-server # Bash LSP
    alejandra # nix formatter
    shfmt # shell formatter
    shellcheck # shell linter
    openfortivpn # VPN
    imagemagick
    pkg-config
    (python313.withPackages (ps:
      with ps; [
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
        pypdf # read/write pdf for editing pdf (replaced deprecated pypdf2)
        python-docx
        scipy
        geopandas
        shapely
        rasterio
        fiona
        requests
      ]))

    #GNOME/KDE
    #gnomeExtensions.paperwm
    #gnomeExtensions.system-monitor
    dconf-editor
    dconf2nix
    #	gnome-themes-extra
    kdePackages.dolphin
    kdePackages.konsole # for terminal in dolphin
    pipewire # for multimedia in dolphin
    libcanberra-gtk3 # missing dependency dolphin
    #gnome-power-manager
    #gnome-tweaks
    #gnome-shell-extensions
    #gnome-shell
    #gnome-system-monitor
    #nautilus
    # Daily apps
    telegram-desktop
    #inkscape
    #inkscape-with-extensions
    #fontconfig
    # These help kitty run under X11
    egl-wayland
    kitty-themes
    # Fonts
    jetbrains-mono
    nerd-fonts.symbols-only
    #python313Full
    #python313Packages.jupyter-client
    #python313Packages.ipykernel
    #python313Packages.pynvim
    #pkgs.gnome-tweaks
    nodejs_24
    pnpm
    # BIOINF
    sratoolkit
    bwa
    bwa-mem2
    blast
    minimap2 # pairwise sequence aligner (pipeline phase)
    seqkit
    qgis
    multiqc
    samtools
    bcftools
    bedtools
    fastqc
    bowtie2
    igv
    macs2
    kent # UCSC Kent utilities (bedGraphToBigWig, etc.)
    fuse # for installing mendeley from appimage file
    # Compile
    cmake
    gcc
    # libs - not correctly installing - often can't find the path to installation - headache with zlib, xml2
    # Conda
    micromamba
    uv # Python package manager (provides uvx)
    # TODO: graphifyy (knowledge-graph Claude skill) installed imperatively:
    #   `uv tool install graphifyy && graphify install`
    #   Migrate to a proper nix derivation once graphifyy or its heavy deps
    #   (graspologic, tree-sitter-*) land in nixpkgs.
    #   Upgrade: `uv tool upgrade graphifyy`
    gws # Google Workspace CLI
    yad # GUI dialogs (used for REC indicator in whisper-stream)
    dos2unix
    tldr
    tree
    presenterm # terminal presentations in markdown

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
  ];
}
