{config, pkgs, lib, inputs, outputs, ...} : {
  config = lib.mkIf config.games.enable {
    home.packages = with pkgs; [
      r2modman
      # minecraft
      prismlauncher
      # flashpoint
      ryubing #ryujinx
      cemu
      # wii u usb helper
    ];
    # steam is in nixos config
  };
}
