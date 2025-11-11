{pkgs, config, lib, ...}:
{


  services.xserver = {
    enable = true;

    displayManager = {
      gdm = {
        enable = true;
        wayland = true;
      };
    };
  };

  programs = {
    hyprland = {
      enable = true;
      xwayland.enable = true;
    };
  };

   
   environment.sessionVariables.NIXOS_OZONE_WL = "1";

   environment.systemPackages = [
      pkgs.kitty # required for the default Hyprland config
   ];
}
