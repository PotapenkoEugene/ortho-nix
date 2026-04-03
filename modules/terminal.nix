{
  config,
  pkgs,
  lib,
  ...
}: {
  programs.kitty = {
    enable = true;
    themeFile = "Dark_Pastel";
    package = config.lib.nixGL.wrap pkgs.kitty;

    font = {
      name = "JetBrains Mono";
      size = 12;
    };

    settings = {
      # Session / remote control (existing)
      startup_session = "~/.config/kitty/session.conf";
      allow_remote_control = "socket-only";
      listen_on = "unix:/tmp/kitty-main";

      # Shell integration — re-enabled for cursor shape + clean resize
      # (prompt jumping features are no-ops inside tmux, no harm)
      shell_integration = "enabled";

      # Nerd Font symbols — delegate to Symbols Nerd Font Mono (don't use patched fonts)
      symbol_map = "U+e000-U+e00a,U+ea60-U+ebeb,U+e0a0-U+e0c8,U+e0ca,U+e0cc-U+e0d7,U+e200-U+e2a9,U+e300-U+e3e3,U+e5fa-U+e6b1,U+e700-U+e7c5,U+ed00-U+efc1,U+f000-U+f2ff,U+f300-U+f372,U+f400-U+f533,U+f0001-U+f1af0 Symbols Nerd Font Mono";

      # Keep ligatures everywhere except under cursor (precise editing, readable display)
      disable_ligatures = "cursor";

      # Performance — reduce latency (default: input_delay 3, repaint_delay 10)
      input_delay = 0;
      repaint_delay = 6;
      sync_to_monitor = "no";

      # Tab bar — powerline slanted at top (Kitty tabs = tmux sessions, different from tmux windows)
      tab_bar_edge = "top";
      tab_bar_style = "powerline";
      tab_powerline_style = "slanted";
      tab_title_template = "{fmt.fg.red}{bell_symbol}{activity_symbol}{fmt.fg.tab}{title}";
      active_tab_font_style = "bold";

      # Tab bar colors — Catppuccin Mocha (matches GNOME + tmux theme)
      active_tab_foreground = "#11111b"; # crust
      active_tab_background = "#cba6f7"; # mauve (distinct from tmux peach)
      inactive_tab_foreground = "#cdd6f4"; # text
      inactive_tab_background = "#181825"; # mantle (same as tmux status bg)
      tab_bar_background = "#181825"; # mantle (matches tmux status bar bg)
      tab_bar_margin_color = "#181825"; # mantle (hides 1px separator between tab bar and content)

      # UI / UX
      confirm_os_window_close = -1; # Always confirm close when processes are running
      mouse_hide_wait = "-1.0"; # Hide cursor immediately when typing
      cursor_shape = "beam"; # Beam cursor (kitty shell integration changes it at prompt)
      cursor_blink_interval = 0; # No blinking
      window_padding_width = "0 4 4"; # top=0 (no gap under tab bar), sides+bottom=4
      hide_window_decorations = "yes"; # Remove OS title bar (no useful info, saves space)
      notify_on_cmd_finish = "invisible 15"; # Desktop alert for commands >15s in background tabs
    };

    keybindings = {
      # Font size — useful for presentations and screen sharing
      "ctrl+shift+equal" = "change_font_size all +1.0";
      "ctrl+shift+minus" = "change_font_size all -1.0";
      "ctrl+shift+0" = "change_font_size all 0";

      # Tab management
      "ctrl+shift+r" = "set_tab_title"; # Rename current tab

      # Kittens
      "ctrl+shift+u" = "kitten unicode_input"; # Unicode character picker
      "ctrl+shift+e" = "kitten hints"; # Keyboard-driven URL/path/hash selection
    };
  };
}
