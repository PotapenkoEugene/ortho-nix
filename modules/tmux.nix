{
  config,
  pkgs,
  lib,
  ...
}: {
  programs.tmux = {
    enable = true;

    # Basic settings
    baseIndex = 1;
    escapeTime = 0;
    historyLimit = 1000000;
    keyMode = "vi";
    mouse = false;
    terminal = "tmux-256color";

    # Prefix key
    prefix = "C-a";

    # Base tmux configuration
    extraConfig = ''
      # Custom keybindings
      # AWS VPN popup
      bind C-y display-popup \
         -d "#{pane_current_path}" \
         -w 80% \
         -h 80% \
         -E "openvpn3 session-start --config ~/evgenip.ovpn"

      # Migal VPN popup (persistent session)
      bind y display-popup -w 80% -h 50% -E "~/.config/home-manager/scripts/vpn-migal-popup.sh"

      # btop popup
      bind t display-popup -w 90% -h 85% -E "btop"

      # lazygit popup
      bind g display-popup -d "#{pane_current_path}" -w 90% -h 85% -E "lazygit"

      # notes popup (persistent nvim session in Orthidian vault)
      bind n display-popup -w 90% -h 90% -E "~/.config/home-manager/scripts/notes-popup.sh"

      # docker browser (tv): images -> drill into containers
      bind d display-popup -w 90% -h 85% -E "tv docker-images"

      # cmatrix screensaver popup
      bind e display-popup -w 100% -h 100% -E "cmatrix -ab"

      # rmpc (music player) popup
      bind m display-popup -w 80% -h 75% -E "rmpc"

      # Reload tmux config
      bind R source-file ~/.config/tmux/tmux.conf \; display-message "Config reloaded"

      # Required for image.nvim
      set -gq allow-passthrough on
      set -g visual-activity off

      # Terminal overrides — true color + undercurl (colored squiggly underlines for Neovim LSP)
      set -as terminal-overrides ',xterm-kitty:RGB'
      set -as terminal-overrides ',*:Smulx=\E[4::%p1%dm'
      set -as terminal-overrides ',*:Setulc=\E[58::2::%p1%{65536}%/%d::%p1%{256}%/%{255}%&%d::%p1%{255}%&%d%;m'

      # Session and window management
      set -g detach-on-destroy off     # don't exit from tmux when closing a session
      set -g renumber-windows on       # renumber all windows when any window is closed
      set -g set-clipboard on          # use system clipboard
      set -g status-position top       # macOS / darwin style

      # Clipboard config
      set -g @override_copy_command 'xclip -selection clipboard'

      # Pane styling
      set -g pane-active-border-style 'fg=magenta,bg=default'
      set -g pane-border-style 'fg=brightblack,bg=default'


      # Window and session management
      bind ^X lock-server
      bind ^C new-window -c "$HOME"
      bind ^D detach
      bind * list-clients

      bind H previous-window
      bind L next-window

      bind r command-prompt "rename-window %%"
      bind ^A last-window
      bind ^W list-windows
      # weather popup (overrides default list-windows)
      bind w display-popup -w 100% -h 100% -E "bash -c 'source ~/.secrets/env && LOC=\$(curl -s ipinfo.io/city) && wego -owm-api-key \$OPENWEATHERMAP_API_KEY -l \$LOC; read -n1'"
      bind z resize-pane -Z
      bind ^L refresh-client
      bind l refresh-client

      # Pane management
      bind | split-window
      bind s display-popup -w 80% -h 60% -E "tv tmux-sessions | xargs -r tmux switch-client -t"
      bind v split-window -h -c "#{pane_current_path}"
      bind '"' choose-window
      bind h select-pane -L
      bind j select-pane -D
      bind k select-pane -U
      bind l select-pane -R

      # Pane resizing
      bind -r -T prefix , resize-pane -L 20
      bind -r -T prefix . resize-pane -R 20
      bind -r -T prefix - resize-pane -D 7
      bind -r -T prefix = resize-pane -U 7

      # Utility bindings
      bind : command-prompt
      bind * setw synchronize-panes
      bind P set pane-border-status
      bind c kill-pane
      bind x swap-pane -D
      bind K send-keys "clear"\; send-keys "Enter"

      # Copy mode
      bind Escape copy-mode
      bind-key -T copy-mode-vi v send-keys -X begin-selection

      # Space: start selection if nothing selected, open nvim popup if selection active
      bind-key -T copy-mode-vi Space if-shell -F "#{selection_active}" \
        "send-keys -X copy-pipe-and-cancel '~/.config/home-manager/scripts/tmux-nvim-scratch.sh'" \
        "send-keys -X begin-selection"

      # Copy mode visual indicator — turns entire status bar red
      set-hook -g pane-mode-changed 'if-shell -F "#{pane_in_mode}" \
        "set status-style bg=#f38ba8,fg=#11111b" \
        "set status-style bg=#181825,fg=#cdd6f4"'
      set-hook -g after-select-window 'if-shell -F "#{pane_in_mode}" \
        "set status-style bg=#f38ba8,fg=#11111b" \
        "set status-style bg=#181825,fg=#cdd6f4"'
      set-hook -g after-select-pane 'if-shell -F "#{pane_in_mode}" \
        "set status-style bg=#f38ba8,fg=#11111b" \
        "set status-style bg=#181825,fg=#cdd6f4"'

      # Only enable continuum auto-save/restore on the main (default) tmux server.
      # Prevents secondary sockets (-L notes, -L vpn) from restoring all sessions.
      %if #{m:*/default,#{socket_path}}
      set -g @continuum-restore 'on'
      set -g @continuum-save-interval '15'
      %else
      set -g @continuum-save-interval '0'
      %endif

      # Keep kitty session.conf current whenever sessions change (no waiting for 5-min timer)
      set-hook -g client-session-changed 'run-shell "~/.config/home-manager/scripts/save-kitty-session.sh"'
      set-hook -g session-closed 'run-shell "~/.config/home-manager/scripts/save-kitty-session.sh"'

      # Catppuccin status bar composition (must be after catppuccin plugin loads)
      set -g status-left-length 120
      set -g status-right-length 100
      set -g status-left "#{E:@catppuccin_status_session}"
      set -g status-right "#{E:@catppuccin_status_directory}#{E:@catppuccin_status_date_time}"
    '';

    # Plugins
    plugins = with pkgs.tmuxPlugins; [
      # Core plugins
      {
        plugin = sensible;
        extraConfig = "";
      }
      {
        plugin = yank;
        extraConfig = "";
      }
      {
        plugin = resurrect;
        extraConfig = ''
          set -g @resurrect-strategy-nvim 'session'
        '';
      }
      {
        plugin = continuum;
        extraConfig = "";
      }
      {
        plugin = tmux-thumbs;
        extraConfig = "";
      }
      {
        plugin = tmux-fzf;
        extraConfig = "";
      }
      {
        plugin = fuzzback.overrideAttrs (old: {
          postInstall =
            (old.postInstall or "")
            + ''
              script=$out/share/tmux-plugins/fuzzback/scripts/.fuzzback.sh-wrapped

              # Inject @fuzzback-query variable after fzf_colors line
              awk '/fzf_colors=.*@fuzzback-fzf-colors/{print; print "  fuzzback_query=\"$(tmux_get \"@fuzzback-query\" \"\")\""; next}1' "$script" > "$script.tmp"
              mv "$script.tmp" "$script"
              chmod +x "$script"

              # Add --query to popup fzf command
              sed -i 's|  fzf-tmux -p "\$1" \\|  fzf-tmux -p "$1" --query "$fuzzback_query" \\|' "$script"

              # Add --query to split finder command
              sed -i 's|  "\$finder" \\|  "$finder" --query "$fuzzback_query" \\|' "$script"
            '';
        });
        extraConfig = ''
          set -g @fuzzback-bind 'f'
          set -g @fuzzback-popup 1
          set -g @fuzzback-popup-size '80%'
          set -g @fuzzback-query 'Ready to code?'
        '';
      }
      {
        plugin = catppuccin;
        extraConfig = ''
          # Catppuccin v2 configuration
          set -g @catppuccin_flavor "mocha"
          set -g @catppuccin_window_status_style "basic"
          set -g @catppuccin_window_number_position "right"
          set -g @catppuccin_window_text " #W"
          set -g @catppuccin_window_current_text " #W"
          set -g @catppuccin_window_number " #I"
          set -g @catppuccin_window_current_number " #I"
          set -g @catppuccin_window_number_color "#{@thm_blue}"
          set -g @catppuccin_window_current_number_color "#{@thm_peach}"
          set -g @catppuccin_window_flags "icon"
          set -g @catppuccin_status_left_separator ""
          set -g @catppuccin_status_right_separator ""
          set -g @catppuccin_status_connect_separator "no"
          set -g @catppuccin_directory_text " #{b:pane_current_path}"
          set -g @catppuccin_date_time_text " %H:%M"
        '';
      }
      # Custom plugins (not available in nixpkgs)
      # Uncomment the ones you want to use and add proper SHA256 hashes

      # tmux-fzf-url plugin
      #       {
      #         plugin = pkgs.tmuxPlugins.mkTmuxPlugin {
      #           pluginName = "tmux-fzf-url";
      #           version = "unstable-2024-01-01";
      #           src = pkgs.fetchFromGitHub {
      #             owner = "wfxr";
      #             repo = "tmux-fzf-url";
      #             rev = "3b4eeea75b594ac61ed2179bff121e07a05e2b32";
      #             sha256 = "";  # Add SHA256 hash here
      #           };
      #         };
      #         extraConfig = ''
      #           set -g @fzf-url-fzf-options '-p 60%,30% --prompt="   " --border-label=" Open URL "'
      #           set -g @fzf-url-history-limit '2000'
      #         '';
      #       }

      # tmux-sessionx plugin
      {
        plugin = pkgs.tmuxPlugins.mkTmuxPlugin {
          pluginName = "sessionx";
          rtpFilePath = "sessionx.tmux";
          version = "unstable-2024-01-01";
          src = pkgs.fetchFromGitHub {
            owner = "omerxx";
            repo = "tmux-sessionx";
            rev = "main";
            sha256 = "sha256-a/wI6UMQayOfQswIm690ypyT/Lxfbz0Uja21ZbqN3Xk=";
          };
        };
        extraConfig = ''
          set -g @sessionx-bind-zo-new-window 'ctrl-y'
          set -g @sessionx-auto-accept 'off'
          set -g @sessionx-custom-paths '~/dotfiles'
          set -g @sessionx-bind 'o'
          set -g @sessionx-x-path '~/dotfiles'
          set -g @sessionx-window-height '85%'
          set -g @sessionx-window-width '75%'
          set -g @sessionx-zoxide-mode 'on'
          set -g @sessionx-custom-paths-subdirectories 'false'
          set -g @sessionx-filter-current 'false'
        '';
      }

      #      # tmux-floax plugin
      {
        plugin = pkgs.tmuxPlugins.mkTmuxPlugin {
          pluginName = "floax";
          rtpFilePath = "floax.tmux";
          version = "unstable-2024-01-01";
          src = pkgs.fetchFromGitHub {
            owner = "omerxx";
            repo = "tmux-floax";
            rev = "main";
            sha256 = "sha256-TCY3W0/4c4KIsY55uClrlzu90XcK/mgbD58WWu6sPrU=";
          };
        };
        extraConfig = ''
          set -g @floax-width '80%'
          set -g @floax-height '80%'
          set -g @floax-border-color 'magenta'
          set -g @floax-text-color 'blue'
          set -g @floax-bind 'p'
          set -g @floax-change-path 'true'
        '';
      }
    ];
  };
}
