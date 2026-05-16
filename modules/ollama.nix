{
  config,
  pkgs,
  lib,
  ...
}:
lib.mkIf pkgs.stdenv.isDarwin {
  home.packages = [pkgs.ollama];

  home.sessionVariables = {
    OLLAMA_KEEP_ALIVE = "-1";
    OLLAMA_MAX_LOADED_MODELS = "3";
  };

  # Pull models on switch — idempotent (skips if already present).
  # ollama pull starts its own server if the daemon isn't up yet.
  home.activation.pullOllamaModels = lib.hm.dag.entryAfter ["writeBoundary"] ''
    if ! ${pkgs.ollama}/bin/ollama list 2>/dev/null | grep -q "qwen2.5:14b"; then
      $DRY_RUN_CMD ${pkgs.ollama}/bin/ollama pull qwen2.5:14b-instruct || true
    fi
    if ! ${pkgs.ollama}/bin/ollama list 2>/dev/null | grep -q "bge-m3"; then
      $DRY_RUN_CMD ${pkgs.ollama}/bin/ollama pull bge-m3 || true
    fi
  '';
}
