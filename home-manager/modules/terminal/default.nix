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

  programs.gh = {
    enable = true;
    settings = {
      git_protocol = "https";
      editor = "hx";
      aliases = {
        co = "pr checkout";
      };
    };
  };

  programs.git = {
    enable = true;
    userName = "kingoftheflame";
    userEmail = "matthew.l.mcclure186@gmail.com";

    extraConfig = {
      credential.helper = "!/home/matthew/.nix-profile/bin/gh auth git-credential";
    };
  };
   
  programs.zellij = {
    enable = true;
  };

  programs.hyfetch ={
    enable = true;
    settings = {
      "preset" = "rainbow";
      "mode" = "rgb";
      "light_dark" = "dark";
      "lightness" = 0.5;
      "color_align" = {
          "mode" = "horizontal";
          "custom_colors" = [];
          "fore_back" = null;
      };
      "backend" = "neofetch";
     };
  };

  programs.bottom.enable = true;

  programs.bat.enable = true;

  programs.ripgrep = {
      enable = true;
  };

}
