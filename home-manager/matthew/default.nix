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
  
  imports = with outputs.homeManagerModules;[
    tools
    vscode

    # Hyprland
    
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

 
  # Add stuff for your user as you see fit:
  # programs.neovim.enable = true;
  # home.packages = with pkgs; [ steam ];

  home.packages = with pkgs; [

  #terminal
    openssh


  #utilities
    rustdesk
    kdePackages.ark
    numbat
  

  #development
    arduino-ide
    teensy-loader-cli
    teensy-udev-rules

    # rpi-imager
    kicad
    
    gtk2    #fix for some program
    podman
    podman-compose

    gcc
    gd

    klayout



  #internet
    firefox-devedition
    google-chrome
    discord

    protonvpn-gui



  #creative software
    #graphics
    krita
    gimp
    blender
    
    #office
    libreoffice
    obsidian    
    kdePackages.ghostwriter


    #music production
    ardour
    audacity



    #gameing
    r2modman      #lethal + etc mod manager
    prismlauncher #minecraft mod launcher
    ryubing       #switch emulator
    cemu          #wii emulator


  #music
    #gui clients
    spotify
    youtube-music
    vlc

    #gui managers
    yt-dlg
    picard

    #cli
    yt-dlp
    ncspot

  

    #find section!!


    
    nixd
    nixpkgs-fmt


    
  ];



  # Enable home-manager 
  programs.home-manager.enable = true;

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "24.05";
}
