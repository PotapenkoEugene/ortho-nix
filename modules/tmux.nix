{ config, pkgs, lib, ... }:
{
  programs.tmux = {
    enable = true;

    # Basic settings
    baseIndex = 1;
    escapeTime = 0;
    historyLimit = 1000000;
    keyMode = "vi";
    mouse = false;
    terminal = "screen-256color";

    # Prefix key
    prefix = "C-a";

    # Base tmux configuration
    extraConfig = ''
      # Custom keybindings
      # VPN popup
      bind C-y display-popup \
         -d "#{pane_current_path}" \
         -w 80% \
         -h 80% \
         -E "openvpn3 session-start --config ~/evgenip.ovpn"

      # Required for image.nvim
      set -gq allow-passthrough on
      set -g visual-activity off

      # Terminal overrides
      set-option -g terminal-overrides ',xterm-256color:RGB'

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
      bind w list-windows
      bind z resize-pane -Z
      bind ^L refresh-client
      bind l refresh-client

      # Pane management
      bind | split-window
      bind s split-window -v -c "#{pane_current_path}"
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
      bind S choose-session
      bind K send-keys "clear"\; send-keys "Enter"

      # Copy mode
      bind-key -T copy-mode-vi v send-keys -X begin-selection
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
        extraConfig = ''
          set -g @continuum-restore 'on'
        '';
      }
      {
        plugin = tmux-thumbs;
        extraConfig = "";
      }
      {
        plugin = tmux-fzf;
        extraConfig = "
          set -g @catppuccin_window_left_separator ''
          set -g @catppuccin_window_right_separator ' '
          set -g @catppuccin_window_middle_separator ' █'
          set -g @catppuccin_window_number_position 'right'
          set -g @catppuccin_window_default_fill 'number'
          set -g @catppuccin_window_default_text '#W'
          set -g @catppuccin_window_current_fill 'number'
          set -g @catppuccin_window_current_text '#W#{?window_zoomed_flag,(),}'
          set -g @catppuccin_status_modules_right 'directory date_time'
          set -g @catppuccin_status_modules_left 'session'
          set -g @catppuccin_status_left_separator  ' '
          set -g @catppuccin_status_right_separator ' '
          set -g @catppuccin_status_right_separator_inverse 'no'
          set -g @catppuccin_status_fill 'icon'
          set -g @catppuccin_status_connect_separator 'no'
          set -g @catppuccin_directory_text '#{b:pane_current_path}'
          set -g @catppuccin_date_time_text '%H:%M'
        ";
      }
      {
        plugin = catppuccin;
        extraConfig = "";
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
          pluginName = "tmux-sessionx";
          version = "unstable-2024-01-01";
          src = pkgs.fetchFromGitHub {
            owner = "omerxx";
            repo = "tmux-sessionx";
            rev = "main";  # or a specific commit
            sha256 = "sha256-SRKI4mliMSMp/Yd+oSn48ArbbRA+szaj70BQeTd8NhM=";  # Add SHA256 hash here
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
          pluginName = "tmux-floax";
          version = "unstable-2024-01-01";
          src = pkgs.fetchFromGitHub {
            owner = "omerxx";
            repo = "tmux-floax";
            rev = "main";  # or a specific commit
            sha256 = "sha256-DOwn7XEg/L95YieUAyZU0FJ49vm2xKGUclm8WCKDizU=";  # Add SHA256 hash here
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
