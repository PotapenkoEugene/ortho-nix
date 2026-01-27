{ config, pkgs, lib, ... }:
{
  programs.nixvim = {
    colorschemes.tokyonight.enable = true;
    highlight.ExtraWhitespace.bg = "red";

    opts = {
      updatetime = 100;
      number = true;
      relativenumber = true;
      shiftwidth = 4;
      swapfile = false;
      undofile = true;
      incsearch = true;
      inccommand = "split";
      ignorecase = true;
      smartcase = true;
      signcolumn = "yes:1";
    };

    globals = {
      mapleader = " ";
      #direnv_auto = 1; # dir environments for project sessions?
      #direnv_silent_load = 0;
    };
  };
}
