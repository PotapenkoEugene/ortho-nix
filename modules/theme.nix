{
  config,
  pkgs,
  lib,
  ...
}: {
  # QT
  qt = {
    platformTheme = {
      name = "qt5ct";
      package = pkgs.libsForQt5.qt5ct;
    };
    style = {
      name = "Darkly";
      package = pkgs.darkly-qt5;
    };
  };

  # GTK
  gtk = {
    enable = true;

    theme = {
      name = "Orchis-Dark";
      package = pkgs.orchis-theme;
    };

    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };

    cursorTheme = {
      name = "Bibata-Modern-Classic";
      package = pkgs.bibata-cursors;
    };
  };
}
