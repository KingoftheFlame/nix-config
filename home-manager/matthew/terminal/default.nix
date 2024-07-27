{ config, pkgs, inputs, ... }:
{
  programs.nushell = {
    enable = true;

    shellAliases = {
      vi = "nvim";
      vim = "nvim";
    };

  };

  programs.starship = {
    enable = true;
  };

  programs.zellij = {
    enable = true;
  };

  programs.hyfetch ={
    enable = true;
  };

  programs.bottom.enable = true;

  programs.bat.enable = true;

  programs.ripgrep = {
      enable = true;
  };

}
