{
  config,
  pkgs,
  lib,
  ...
}: {
  home.packages = with pkgs; [
    llama-cpp-vulkan
  ];

  # Download model on first `home-manager switch` (idempotent, skips if exists)
  home.activation.downloadLlmModel = lib.hm.dag.entryAfter ["writeBoundary"] ''
    MODEL_DIR="${config.home.homeDirectory}/llm-models"
    MODEL_FILE="$MODEL_DIR/qwen2.5-3b-instruct-q4_k_m.gguf"
    if [ ! -f "$MODEL_FILE" ]; then
      mkdir -p "$MODEL_DIR"
      echo "Downloading Qwen2.5-3B-Instruct Q4_K_M (~2.1GB)..."
      ${pkgs.aria2}/bin/aria2c \
        --dir="$MODEL_DIR" \
        --out="qwen2.5-3b-instruct-q4_k_m.gguf" \
        --max-connection-per-server=8 --split=8 --continue=true \
        "https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF/resolve/main/qwen2.5-3b-instruct-q4_k_m.gguf"
    fi
  '';

  # Download Whisper medium.en model on first `home-manager switch` (idempotent)
  home.activation.downloadWhisperModel = lib.hm.dag.entryAfter ["writeBoundary"] ''
    MODEL_FILE="${config.home.homeDirectory}/whisper-models/ggml-medium.en.bin"
    if [ ! -f "$MODEL_FILE" ]; then
      mkdir -p "$(dirname "$MODEL_FILE")"
      echo "Downloading Whisper medium.en model (~1.5GB)..."
      ${pkgs.aria2}/bin/aria2c \
        --dir="$(dirname "$MODEL_FILE")" \
        --out="ggml-medium.en.bin" \
        --max-connection-per-server=8 --split=8 --continue=true \
        "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.en.bin"
    fi
  '';
}
