{
  inputs,
  outputs,
  lib,
  config,
  pkgs,
  ...
}: 
{
  imports =
    with outputs.nixosModules;[ # Include the results of the hardware scan.
      
      ./hardware-configuration.nix

      system
      virtualisation
      gaming
      bluetooth
      
      inputs.home-manager.nixosModules.home-manager	
      # Hyprland
    ];

  #options for imported modules
  virt_members = ["matthew"];
  

  #package manager configuretion
  nixpkgs = {
    overlays = [
      outputs.overlays.additions
      outputs.overlays.modifications
      outputs.overlays.unstable-packages

      ];

      config = {
        allowUnfree = true;
      };
    };

  nix.settings.experimental-features = "nix-command flakes";
   
  #enable app image programs
  programs.appimage.enable = true;
  programs.appimage.binfmt = true;
     
  

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;


  #cross compile raspberry pi
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  networking.hostName = "nix-laptop"; # Define your hostname.


  # Enable networking
  networking.networkmanager.enable = true;
 

  # Set your time zone.
  time.timeZone = "America/Chicago";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };


  # Configure keymap in X11
  services.xserver = {
    enable = true;
    xkb.layout = "us";
    xkb.variant = "";
  };

  # Enable the Desktop Environment.
  services.xserver.displayManager.lightdm.enable = true;
  # services.xserver.displayManager.sddm.enable = true;
  # services.displayManager.sddm.wayland.enable  = true;
  
  # services.xserver.desktopManager.cinnamon.enable = true; #alright
  # services.xserver.desktopManager.xfce.enable = true; #good top bar, macos bottom panel
  # services.xserver.desktopManager.mate.enable = true; #windows xp ah dm
  services.xserver.desktopManager.budgie.enable = true; #cinnamon but better


  #enable homemanager
  programs.hyprland.enable = true;
  programs.hyprland.package = inputs.hyprland.packages."${pkgs.system}".hyprland;
   environment.sessionVariables.NIXOS_OZONE_WL = "1";
  

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.matthew = {
    isNormalUser = true;
    description = "Matthew M";
    extraGroups = [ "networkmanager" "wheel" "audio" "docker"];
    packages = with pkgs; [
    #  thunderbird
    ];
    shell = pkgs.nushell;
  };

  users.defaultUserShell = pkgs.nushell;

  environment.systemPackages = with pkgs; [
    nushell
    gtk3
  ];


  services.tailscale.enable = true;
  services.tailscale.useRoutingFeatures = "client";
  


  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.05"; # Did you read the comment?

}
