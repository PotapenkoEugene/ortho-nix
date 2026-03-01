{
  config,
  pkgs,
  lib,
  ...
}: {
  home.sessionPath = [
    "/home/ortho/Tools/Bioscripts"
    "$HOME/.npm-global/bin"
    "$HOME/.config/home-manager/scripts"
  ];

  programs.bash = {
    enable = true;
    shellAliases = {
      ls = "eza --color=always --group-directories-first";
      ll = "eza -la --color=always --group-directories-first --sort new";
      "..." = "cd ../../";
      #rstudio = "rstudio --no-sandbox"; # for installation  via nix (not worked properly)
      #	    clip="xclip -selection clipboard";
      fzfp = "fzf --preview='cat {}'";

      # Whisper speech-to-text (using compiled version from ~/Tools)
      whisper = "whisper-cli -m ~/whisper-models/ggml-medium.en.bin";

      # Piper text-to-speech with pre-downloaded model
      piper-tts = "piper --model ~/piper-models/en_US-lessac-medium.onnx";

      # Local LLM (Qwen2.5-3B) — interactive chat
      llm = "llama-cli -m ~/llm-models/qwen2.5-3b-instruct-q4_k_m.gguf --threads 12 --ctx-size 8192 -ngl 99 --no-display-prompt --log-disable -cnv";

      # WORKAROUND: tmux 3.6a has "open terminal failed: not a terminal" bug with xterm-kitty
      tmux = "/nix/store/msrldc9bfz6piaa0704m0djjm14mq151-tmux-3.5a/bin/tmux";
      tb = "tmux attach -t base";

      vpn_migal = "sudo /home/ortho/.nix-profile/bin/openfortivpn";
      vpn_aws_close = "openvpn3 sessions-list | grep Path | tr -s ' ' | cut -f3 -d ' ' | xargs -I {} openvpn3 session-manage --session-path {} --disconnect";
      aws = "ssh evgenip@172.31.186.68";
      migal = "ssh -o IdentitiesOnly=yes -i ~/.ssh/id_rsa potapgene@172.16.11.55";
      migal_8484 = "ssh -o IdentitiesOnly=yes -i ~/.ssh/id_rsa -L 8484:localhost:8484 potapgene@172.16.11.55";
      migal_8585 = "ssh -o IdentitiesOnly=yes -i ~/.ssh/id_rsa -L 8585:localhost:8585 potapgene@172.16.11.55";
    };
    initExtra = ''
      [ -f ~/.secrets/env ] && source ~/.secrets/env
      export PKG_CONFIG_PATH="${pkgs.imagemagick.dev}/lib/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig:/usr/lib/pkgconfig:/usr/share/pkgconfig"
      export PATH=~/.local/bin/:$PATH
      export CFLAGS="-I/usr/include"
      export LDFLAGS="-L/usr/lib/x86_64-linux-gnu"
      export RSTUDIO_WHICH_R="/home/ortho/micromamba/envs/R42/bin/R"
      set -o vi
      cc() {
        local content
        content=$(base64 | tr -d '\n')
        printf '\033]52;c;%s\a' "$content"
      }
    '';
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
