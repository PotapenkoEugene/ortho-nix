{
  config,
  pkgs,
  lib,
  ...
}: {
  home.sessionPath =
    [
      "$HOME/.npm-global/bin"
      "$HOME/.config/home-manager/scripts"
    ]
    ++ lib.optionals pkgs.stdenv.isLinux [
      "/home/ortho/Tools/Bioscripts"
    ];

  programs.bash = {
    enable = true;
    shellAliases =
      {
        bat = "bat --color=always";
        ls = "eza --color=always --group-directories-first";
        ll = "eza -la --color=always --group-directories-first --sort new";
        "..." = "cd ../../";
        fzfp = "fzf --preview='cat {}'";

        # Whisper speech-to-text via Groq API (ad-hoc file transcription)
        whisper = "bash -c 'source ~/.secrets/env; flac=$(mktemp /tmp/whisper-XXXXXX.flac); ffmpeg -y -i \"$1\" -ar 16000 -ac 1 \"$flac\" 2>/dev/null && curl -s https://api.groq.com/openai/v1/audio/transcriptions -H \"Authorization: Bearer $GROQ_API_KEY\" -F \"file=@$flac\" -F \"model=whisper-large-v3-turbo\" -F \"response_format=text\"; rm -f \"$flac\"' _ ";

        # Piper text-to-speech with pre-downloaded model
        piper-tts = "piper --model ~/piper-models/en_US-lessac-medium.onnx";

        claude = "claude --effort xhigh --enable-auto-mode \"What to do next /note\"";
        claude_he = "claude --effort high \"What to do next /note\"";
        tb = "tmux attach -t base";

        # kitten ssh: auto-copies kitty terminfo to remote hosts (fixes xterm-kitty unknown terminal)
        kssh = "kitten ssh";

        mac = "ssh mac-studio";
        aws = "ssh evgenip@172.31.186.68";
        migal = "ssh -o IdentitiesOnly=yes -i ~/.ssh/id_rsa potapgene@172.16.11.55";
        migal_8484 = "ssh -o IdentitiesOnly=yes -i ~/.ssh/id_rsa -L 8484:localhost:8484 potapgene@172.16.11.55";
        migal_8585 = "ssh -o IdentitiesOnly=yes -i ~/.ssh/id_rsa -L 8585:localhost:8585 potapgene@172.16.11.55";
      }
      // lib.optionalAttrs pkgs.stdenv.isLinux {
        dolphin = "dolphin $PWD";
        vpn_migal = "sudo /home/ortho/.nix-profile/bin/openfortivpn";
        vpn_aws_close = "openvpn3 sessions-list | grep Path | tr -s ' ' | cut -f3 -d ' ' | xargs -I {} openvpn3 session-manage --session-path {} --disconnect";
        # Local LLM (Qwen2.5-3B via llama-cpp-vulkan, iGPU-accelerated)
        llm = "llama-cli -m ~/llm-models/qwen2.5-3b-instruct-q4_k_m.gguf --threads 12 --ctx-size 8192 -ngl 99 --no-display-prompt --log-disable -cnv";
      }
      // lib.optionalAttrs pkgs.stdenv.isDarwin {
        # Local LLM (Qwen2.5-14B via Ollama MLX backend)
        llm = "ollama run qwen2.5:14b-instruct";
      };
    initExtra =
      ''
        [ -f ~/.secrets/env ] && source ~/.secrets/env
        export PATH=~/.local/bin/:$PATH
        export EDITOR="$HOME/.config/home-manager/scripts/nvim-editor-popup.sh"
        export VISUAL="$HOME/.config/home-manager/scripts/nvim-editor-popup.sh"
        export MAMBA_ROOT_PREFIX="$HOME/micromamba"
        export PLAYWRIGHT_BROWSERS_PATH="$HOME/.cache/ms-playwright"
        set -o vi
        eval "$(tv init bash)"
        bind -r '"\C-T"'
        bind -x '"\C-F": tv_smart_autocomplete'
        bind -x '"\C-H": tv_shell_history'
        cc() {
          local content
          content=$(base64 | tr -d '\n')
          printf '\033]52;c;%s\a' "$content"
        }
        pterm() {
          command presenterm -x "$1" --publish-speaker-notes
        }
        pterm-notes() {
          command presenterm -x "$1" --listen-speaker-notes
        }
        playwright-cli() {
          if [ ! -f ".playwright/cli.config.json" ] && [ "$1" != "install" ]; then
            command playwright-cli install >/dev/null 2>&1
          fi
          command playwright-cli "$@"
        }
      ''
      + lib.optionalString pkgs.stdenv.isLinux ''
        export PKG_CONFIG_PATH="${pkgs.imagemagick.dev}/lib/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig:/usr/lib/pkgconfig:/usr/share/pkgconfig"
        export CFLAGS="-I/usr/include"
        export LDFLAGS="-L/usr/lib/x86_64-linux-gnu"
        export RSTUDIO_WHICH_R="/home/ortho/micromamba/envs/R42/bin/R"
      '';
  };

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks = {
      "*" = {
        addKeysToAgent = "no";
        userKnownHostsFile = "~/.ssh/known_hosts";
        hashKnownHosts = false;
        serverAliveInterval = 60;
      };
      "mac-studio" = {
        hostname = "100.68.68.16";
        user = "ortho";
        identityFile = "~/.ssh/mac_studio_ed25519";
        identitiesOnly = true;
      };
      "github-personal" = {
        hostname = "github.com";
        user = "git";
        identityFile = "~/.ssh/id_github_ed25519";
        identitiesOnly = true;
      };
      "github-hubner" = {
        hostname = "github.com";
        user = "git";
        identityFile = "~/.ssh/hubnergit_ed25519";
        identitiesOnly = true;
      };
    };
  };

  programs.fzf = {
    enable = true;
    enableBashIntegration = true;
  };

  programs.zoxide = {
    enable = true;
    enableBashIntegration = true;
    options = ["--cmd cd"]; # replaces cd with zoxide
  };
}
