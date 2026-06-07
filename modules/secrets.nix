{
  config,
  lib,
  ...
}:
lib.mkIf (builtins.pathExists ../secrets/common.yaml && !config.ortho.headless) {
  # sops-nix needs parent dir to exist before activation
  home.activation.createSopsDir = lib.hm.dag.entryBefore ["writeBoundary"] ''
    mkdir -p "${config.home.homeDirectory}/.config/sops-nix"
  '';

  sops = {
    defaultSopsFile = ../secrets/common.yaml;
    age = {
      keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
      generateKey = false;
    };
    # Use defaultSymlinkPath for HM-level sops (simpler than mount point mechanism)
    defaultSymlinkPath = "${config.home.homeDirectory}/.config/sops-nix/secrets";
    defaultSecretsMountPoint = "%r/secrets.d";

    secrets = {
      "openai/api_key" = {};
      "openweathermap/api_key" = {};
      "google_oauth/client_id" = {};
      "google_oauth/client_secret" = {};
      "google_oauth/credentials_json" = {};
      "groq/api_key" = {};
      "anthropic/api_key" = {};
      "tgbot/bot_token" = {};
      "cfbot/bot_token" = {};
      "askbot/bot_token" = {};
      "askbot/allowed_user_ids" = {};
    };

    templates."secrets.env" = {
      mode = "0400";
      content = ''
        export OPENAI_API_KEY="${config.sops.placeholder."openai/api_key"}"
        export OPENWEATHERMAP_API_KEY="${config.sops.placeholder."openweathermap/api_key"}"
        export GOOGLE_OAUTH_CLIENT_ID="${config.sops.placeholder."google_oauth/client_id"}"
        export GOOGLE_OAUTH_CLIENT_SECRET="${config.sops.placeholder."google_oauth/client_secret"}"
        export GROQ_API_KEY="${config.sops.placeholder."groq/api_key"}"
        export ASKBOT_BOT_TOKEN="${config.sops.placeholder."askbot/bot_token"}"
        export ASKBOT_ALLOWED_USER_IDS="${config.sops.placeholder."askbot/allowed_user_ids"}"
      '';
    };
  };
}
