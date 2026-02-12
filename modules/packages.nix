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
    xan
    # Music
    mpd
    yt-dlp
    ffmpeg
    # Remote Connect
    #rustdesk
    #anydesk
    #nomachine-client
    # file managers
    ripgrep # Often used with fzf
    fd # Modern find alternative, works well with fzf
    eza # color alternative for ls
    bat # cat with syntax highlight
    duf # disk usage overview
    # clipboard
    xclip
    wl-clipboard
    #Office
    aria2
    zathura
    libreoffice
    pdftk
    brightnessctl
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
    (python312.withPackages (ps:
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
        pypdf2 # read/write pdf for editing pdf
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
    #python312Full
    #python312Packages.jupyter-client
    #python312Packages.ipykernel
    #python312Packages.pynvim
    #pkgs.gnome-tweaks
    nodejs_24
    # BIOINF
    multiqc
    samtools
    bcftools
    bedtools
    fastqc
    bowtie2
    igv
    macs2
    fuse # for installing mendeley from appimage file
    # Compile
    cmake
    gcc
    # libs - not correctly installing - often can't find the path to installation - headache with zlib, xml2
    # Conda
    micromamba

    # R
    #	(rWrapper.override { # works strangely for now, install by hand
    #	  R = pkgs.R;
    #	  packages = with rPackages; [
    #	    tidyverse
    #	    gt
    #	    ggpubr
    #	    svglite
    #	    data_table
    #	    IRkernel
    #	    ggplot2
    #	    dplyr
    #	  ];
    #	})
  ];
}
