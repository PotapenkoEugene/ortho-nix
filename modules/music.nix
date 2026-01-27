{ config, pkgs, lib, ... }:
{
  programs.rmpc = {
    enable = true;
    config = ''
      (
        address: "/run/user/1000/mpd.sock",
        cache_dir: Some("/home/ortho/.cache/rmpc/"),
      )
    '';
  };

  services.mpd = {
    enable = true;
    musicDirectory = "/home/ortho/Music";
    extraConfig = ''
      audio_output {
        type "pulse"
        name "PulseAudio"
      }
      bind_to_address "/run/user/1000/mpd.sock"
    '';
  };

  # Torrent
  #programs.rtorrent = {
  #    enable = true;
  #        extraConfig = ''
  #          upload_rate = 1000
  #          directory = /home/ortho/incoming
  #          session = /home/ortho/incoming/.rtorrent
  #          port_range = 6900-6999
  #          encryption = allow_incoming,try_outgoing,enable_retry
  #          dht = on
  #          schedule = watch_directory,5,5,load_start=/home/ortho/incoming/watch/*.torrent
  #        '';
  #};
}
