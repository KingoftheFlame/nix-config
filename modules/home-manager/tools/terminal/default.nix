{ config, pkgs, lib, inputs, outputs,  ... }:
{


  programs.nushell = let envStrs = []; in{
    enable = true;

    shellAliases = {
      vi = "nvim";
      vim = "nvim";
    };

    envFile.source = ./env.nu;
    configFile.source = ./config.nu;

    extraEnv = ''
      $env.scripts_path = '${pkgs.nu_scripts}/share/nu_scripts'
    '';


  };


  #WSL
  # programs.nushell.extraEnv = lib.mkIf(config.wsl.enable) programs.nushell.extraEnv + "$env.BROWSER = \'wslview\'";
  
  # home.file.".config/nushell/nu_scripts".source = outputs.nu-scripts;
  home.packages = with pkgs;[
    nu_scripts
    speedtest-rs
    wormhole-rs
    streamlink
  ];
   

  programs.helix = {
    enable = true;
    languages = {
      nix = {formatter = "nixpkgs-fmt";};
    };
  };

  programs.starship = {
    enable = true;
    enableNushellIntegration = true;
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
    extensions = [pkgs.gh-dash];
  };

  programs.gh-dash = {
    enable = true;
  };

  programs.git = {
    enable = true;
    userName = "kingoftheflame";
    userEmail = "matthew.l.mcclure186@gmail.com";
  };
   
  programs.zellij = {
    enable = true;
  };

  programs.hyfetch ={
    enable = true;
    settings = {
      "preset" = "gay-men";
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

  programs.bottom = {
    enable = true;
    settings = {
      #fill out when I give a shit
    };
  };

  programs.bat = {
    enable = true;
    #add configuration when you care
  };

  programs.ripgrep = {
      enable = true;
  };

}
