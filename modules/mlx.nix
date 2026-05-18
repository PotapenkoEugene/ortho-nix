{
  config,
  pkgs,
  lib,
  ...
}:
lib.mkIf pkgs.stdenv.isDarwin {
  # HuggingFace model cache — shared with the mlx_lm.server launchd agent (defined in ortho-mac-system.nix).
  home.sessionVariables.HF_HOME = "${config.home.homeDirectory}/.cache/huggingface";
}
