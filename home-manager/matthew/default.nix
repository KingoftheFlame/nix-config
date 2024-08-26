# This is your home-manager configuration file
# Use this to configure your home environment (it replaces ~/.config/nixpkgs/home.nix)
{
  inputs,
  outputs,
  lib,
  config,
  pkgs,
  ...
}: {
  # You can import other home-manager modules here
  imports = [
    # If you want to use modules your own flake exports (from modules/home-manager):
    # outputs.homeManagerModules.example

    # Or modules exported from other flakes (such as nix-colors):
    # inputs.nix-colors.homeManagerModules.default
    ../modules/terminal
    ../modules/neovim
  ];


  nixpkgs = {
    # You can add overlays here
    overlays = [
      # Add overlays your own flake exports (from overlays and pkgs dir):
      outputs.overlays.additions
      outputs.overlays.modifications
      outputs.overlays.unstable-packages

      # You can also add overlays exported from other flakes:
      # neovim-nightly-overlay.overlays.default

      # Or define it inline, for example:
      # (final: prev: {
      #   hi = final.hello.overrideAttrs (oldAttrs: {
      #     patches = [ ./change-hello-to-hi.patch ];
      #   });
      # })
    ];
    # Configure your nixpkgs instance
    config = {
      # Disable if you don't want unfree packages
      allowUnfree = true;
    };
  };

  nix = {
    package = pkgs.nix;
    settings.experimental-features = [ "nix-command" "flakes" ];
  };

  home = {
    username = "matthew";
    homeDirectory = "/home/matthew";
  };

  #Todo: Figure out how to add this to flake in order to avoid the suffering of updating the rev
  # home.file.".config/nushell/nu_scripts".source = pkgs.fetchgit {
  #   url = "https://github.com/nushell/nu_scripts.git";
  #   rev = "54546c8bf2ea69768eec2acf4c6cbfce4e879dff";
  #   hash = "sha256-S3ORCFLm4OduqBqp7jTSBhXAMiO29irXYy5My8p1yT0=";
  # }; 

  home.file.".config/nushell/nu_scripts".source = outputs.nu-scripts;
  
  # Add stuff for your user as you see fit:
  # programs.neovim.enable = true;
  # home.packages = with pkgs; [ steam ];

  home.packages = with pkgs; [
    openssh

    git
    gh
  
    gcc
    pnpm
    python3
    rustup

    helix

    lua-language-server
    nixd

    android-studio

    #strawberry

    wslu

    cloudflared

  ];



  # Enable home-manager 
  programs.home-manager.enable = true;

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "24.05";
}
