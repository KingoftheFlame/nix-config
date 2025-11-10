{ config, pkgs, lib, inputs, outputs,  ... }:
{

  config = {
    programs.nushell = lib.mkMerge [
      {
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

        extraConfig = ''
          source ${pkgs.nu_scripts}/share/nu_scripts/custom-completions/adb/adb-completions.nu
          source ${pkgs.nu_scripts}/share/nu_scripts/custom-completions/bat/bat-completions.nu
          source ${pkgs.nu_scripts}/share/nu_scripts/custom-completions/btm/btm-completions.nu         
          source ${pkgs.nu_scripts}/share/nu_scripts/custom-completions/cargo/cargo-completions.nu
          source ${pkgs.nu_scripts}/share/nu_scripts/custom-completions/curl/curl-completions.nu
          source ${pkgs.nu_scripts}/share/nu_scripts/custom-completions/docker/docker-completions.nu
          source ${pkgs.nu_scripts}/share/nu_scripts/custom-completions/eza/eza-completions.nu
          source ${pkgs.nu_scripts}/share/nu_scripts/custom-completions/git/git-completions.nu
          source ${pkgs.nu_scripts}/share/nu_scripts/custom-completions/gh/gh-completions.nu
          source ${pkgs.nu_scripts}/share/nu_scripts/custom-completions/nix/nix-completions.nu
          source ${pkgs.nu_scripts}/share/nu_scripts/custom-completions/npm/npm-completions.nu
          source ${pkgs.nu_scripts}/share/nu_scripts/custom-completions/pnpm/pnpm-completions.nu
          source ${pkgs.nu_scripts}/share/nu_scripts/custom-completions/rg/rg-completions.nu
          source ${pkgs.nu_scripts}/share/nu_scripts/custom-completions/rustup/rustup-completions.nu
          source ${pkgs.nu_scripts}/share/nu_scripts/custom-completions/scoop/scoop-completions.nu
          source ${pkgs.nu_scripts}/share/nu_scripts/custom-completions/tar/tar-completions.nu
          source ${pkgs.nu_scripts}/share/nu_scripts/custom-completions/vscode/vscode-completions.nu
          source ${pkgs.nu_scripts}/share/nu_scripts/custom-completions/zellij/zellij-completions.nu
          source ${pkgs.nu_scripts}/share/nu_scripts/custom-completions/zoxide/zoxide-completions.nu
        '';
      }

      {
          extraEnv = lib.mkIf(config.is-wsl) "
            $env.BROWSER = \'wslview\'
            alias code = code.exe
          ";
      }

    ];


    #WSL
    # programs.nushell.extraEnv = lib.mkIf(config.wsl.enable) programs.nushell.extraEnv + "$env.BROWSER = \'wslview\'";
    
    # home.file.".config/nushell/nu_scripts".source = outputs.nu-scripts;
    home.packages = with pkgs;[
      nu_scripts

      speedtest-rs
      hyperfine

      wormhole-rs
      streamlink

      #replacements
      bottom
      bat
      ripgrep
      fd
      eza
      #zoxide

      xh
      gitui
      dust

      yazi

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

    # programs.gh-dash = {
    #   enable = true;
    # };

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
  
  };

}
