{pkgs, config, lib, ...}:
{
  
  #steam
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
    dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
  };

  hardware.steam-hardware.enable = true;
  # hardware.xone.enable = true;
  environment.systemPackages = with pkgs;[
    # linuxKernel.packages.linux_zen.xone
    # linuxKernel.packages.linux_zen.xpadneo
  ];

  # environment.systemPackages = with pkgs;[
  #   xboxdrv
  # ];
  boot.extraModprobeConfig = '' options bluetooth disable_ertm=1 '';
}
