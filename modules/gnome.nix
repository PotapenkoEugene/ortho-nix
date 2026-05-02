{
  config,
  pkgs,
  lib,
  ...
}: let
  catppuccinGtk = pkgs.magnetic-catppuccin-gtk;
  catppuccinShell = "${catppuccinGtk}/share/themes/Catppuccin-GTK-Dark/gnome-shell";
in {
  # Wrapper GNOME Shell theme — imports Catppuccin-GTK-Dark and overrides panel bg to #181825 (mantle)
  # to match Kitty tab bar and tmux status bar. Only gnome-shell.css is overridden; assets symlinked.
  home.file = {
    ".local/share/themes/Catppuccin-Custom/gnome-shell/gnome-shell.css".text = ''
      @import url("file://${catppuccinShell}/gnome-shell.css");

      #panel {
        background-color: #181825;
      }
      #panel .panel-corner {
        -panel-corner-background-color: #181825;
      }
    '';
    ".local/share/themes/Catppuccin-Custom/gnome-shell/pad-osd.css".source = "${catppuccinShell}/pad-osd.css";
    ".local/share/themes/Catppuccin-Custom/gnome-shell/no-events.svg".source = "${catppuccinShell}/no-events.svg";
    ".local/share/themes/Catppuccin-Custom/gnome-shell/no-notifications.svg".source = "${catppuccinShell}/no-notifications.svg";
    ".local/share/themes/Catppuccin-Custom/gnome-shell/process-working.svg".source = "${catppuccinShell}/process-working.svg";
    ".local/share/themes/Catppuccin-Custom/gnome-shell/assets".source = "${catppuccinShell}/assets";
  };
  programs.gnome-shell = {
    enable = true;
    extensions = [
      # !!! required restart system - not only log out/in
      {package = pkgs.gnomeExtensions.tiling-shell;}
      #	    { package = pkgs.gnomeExtensions.caffeine; }
      {package = pkgs.gnomeExtensions.clipboard-indicator;}
      {package = pkgs.gnomeExtensions.astra-monitor;}
      {package = pkgs.gnomeExtensions.user-themes;}
      {package = pkgs.gnomeExtensions.just-perfection;}
    ];
  };

  dconf = {
    enable = true;
    settings = {
      "org/gnome/shell/extensions/user-theme" = {
        name = "Catppuccin-Custom";
      };
      "org/gnome/shell/extensions/just-perfection" = {
        activities-button = false;
        notification-banner-position = 2; # top-right (default 1 = center)
      };
      "org/gnome/settings-daemon/plugins/power" = {
        sleep-inactive-ac-type = "nothing";
        sleep-inactive-battery-type = "nothing";
      };
      "org/gnome/desktop/session" = {
        idle-delay = lib.hm.gvariant.mkUint32 0;
      };
      "org/gnome/desktop/wm/keybindings" = {
        # Next input source
        "switch-input-source" = ["<Alt>Shift_L"];
      };
      "org/gnome/desktop/input-sources" = {
        sources = [
          (lib.hm.gvariant.mkTuple ["xkb" "us"])
          (lib.hm.gvariant.mkTuple ["xkb" "ru"])
        ];
        per-window = true; # each window remembers its own language
        # Remap Caps Lock to Escape (fixes LED desync on login + useful for vim)
        xkb-options = ["caps:escape"];
      };
      "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
        name = "Brightness to Zero";
        command = "${pkgs.brightnessctl}/bin/brightnessctl s 0";
        binding = "<Control>F5";
      };
      "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1" = {
        name = "Launch kitty";
        command = "sh -c 'setsid kitty &>/dev/null &'";
        binding = "<Alt>t";
      };
      "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2" = {
        name = "Launch Dolphin";
        command = "sh -c 'setsid dolphin &>/dev/null &'";
        binding = "<Alt>d";
      };
      "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3" = {
        name = "Whisper Stream Toggle";
        command = "/home/ortho/.config/home-manager/scripts/whisper-stream-toggle.sh";
        binding = "F8";
      };
      "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom4" = {
        name = "Connect AirPods";
        command = "bluetoothctl connect C4:B3:49:8F:63:42";
        binding = "<Super>b";
      };
      "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom5" = {
        name = "Toggle Lofi";
        command = "/home/ortho/.config/home-manager/scripts/lofi-toggle.sh";
        binding = "<Super>l";
      };
      "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom6" = {
        name = "Launch Telegram";
        command = "sh -c 'setsid Telegram &>/dev/null &'";
        binding = "<Super>t";
      };
      "org/gnome/settings-daemon/plugins/media-keys" = {
        screensaver = [""]; # disable default Super+L lock screen
        custom-keybindings = [
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/"
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/"
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3/"
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom4/"
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom5/"
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom6/"
        ];
      };
      # Disable middle-click paste
      "org/gnome/shell/keybindings" = {
        toggle-message-tray = ["<Super>v"];
      };
      "org/gnome/desktop/interface" = {
        gtk-enable-primary-paste = false;
      };
      "org/gnome/shell" = {
        disable-user-extensions = false;
        disable-extension-version-validation = true;
        disabled-extensions = [
          "ubuntu-dock@ubuntu.com"
          "tiling-assistant@ubuntu.com"
        ];
      };
      "org/gnome/desktop/interface".show-battery-percentage = true;
      "org/gnome/shell/extensions/appindicator" = {
        icon-brightness = -0.1;
        icon-opacity = 255;
        icon-saturation = 0.8;
        icon-size = 18;
        tray-pos = "right";
      };
      "org/gnome/shell/extensions/blur-my-shell/panel" = {
        blur = true;
        brightness = 0.6;
        sigma = 0;
        static-blur = false;
        style-panel = 3;
      };

      "org/gnome/shell/extensions/caffeine" = {
        indicator-position = -1;
        indicator-position-index = -1;
        screen-blank = "never";
        show-indicator = "only-active";
        show-notifications = false;
        toggle-shortcut = ["<Super>c"];
      };
      "org/gnome/shell/extensions/clipboard-indicator" = {
        cache-size = 10;
        disable-down-arrow = false;
        display-mode = 0;
        history-size = 200;
        strip-text = true;
        topbar-preview-size = 8;

        clear-history = [];
        private-mode-binding = [];
        toggle-menu = ["<Super><Control>v"];
      };
      "org/gnome/shell/extensions/astra-monitor" = {
        panel-box = "left";
        panel-box-order = 0;
      };
      "org/gnome/shell/extensions/unite" = {
        extend-left-box = false;
        greyscale-tray-icons = false;
        hide-app-menu-icon = true;
        use-activities-text = true;
      };

      #"org/gnome/shell/extensions/paperwm@hedning:matrix.org" = {
      #	enable = true;
      #							};
    };
  };
}
