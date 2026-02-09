{host, pkgs, ...}: let
  vars = import ../variables.nix;
  inherit
    (vars)
    ;
  # Select bar module based on barChoice
in {
  imports =
    [
      ./overview.nix
      ./emoji.nix
      ./gtk.nix
      ./hyprland
      ./terminals/kitty.nix
      ./rofi
      ./qt.nix
      ./stylix.nix
      ./swappy.nix
      ./swaync.nix
      ./wlogout
      ./xdg.nix
      ./editors/vscode.nix
    ];
}
