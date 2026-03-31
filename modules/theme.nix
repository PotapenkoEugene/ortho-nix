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
      name = "Catppuccin-GTK-Dark";
      package = pkgs.magnetic-catppuccin-gtk;
    };

    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };

    cursorTheme = {
      name = "catppuccin-mocha-peach-cursors";
      package = pkgs.catppuccin-cursors.mochaPeach;
    };
  };
}
