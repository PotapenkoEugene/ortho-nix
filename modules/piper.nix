{
  config,
  pkgs,
  lib,
  ...
}: {
  home.packages = with pkgs; [
    piper-tts
  ];

  home.file = {
    "piper-models/en_US-lessac-medium.onnx".source = pkgs.fetchurl {
      url = "https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium/en_US-lessac-medium.onnx";
      sha256 = "17q1mzm6xd5i2rxx2xwqkxvfx796kmp1lvk4mwkph602k7k0kzjy";
    };
    "piper-models/en_US-lessac-medium.onnx.json".source = pkgs.fetchurl {
      url = "https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium/en_US-lessac-medium.onnx.json";
      sha256 = "184hnvd8389xpdm0x2w6phss23v5pb34i0lhd4nmy1gdgd0rrqgg";
    };
  };
}
