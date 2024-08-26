{ config, pkgs, inputs, outputs,  ... }:
{
  programs.nushell = {
    enable = true;

    shellAliases = {
      vi = "nvim";
      vim = "nvim";
    };

    configFile.source = ./config.nu;
    envFile.source = ./env.nu;

  };

  home.file.".config/nushell/nu_scripts".source = outputs.nu-scripts;

  programs.starship = {
    enable = true;
    settings = {
      format = "$all$directory$character";
    };
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
