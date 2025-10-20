{pkgs, config, lib, ...}:
{
   programs.hyprland.enable = true;

   environment.sessionVariables.NIXOS_OZONE_WL = "1";

   environment.systemPackages = [
      pkgs.kitty # required for the default Hyprland config
   ];
}
