{pkgs, config, lib, ...}:
{
  
  #steam
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
    dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
  };

  # environment.systemPackages = with pkgs;[
  #   xboxdrv
  # ];
  boot.extraModprobeConfig = '' options bluetooth disable_ertm=1 '';
}
