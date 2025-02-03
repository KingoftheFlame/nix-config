{config, pkgs, lib, inputs, outputs, ...} : {
  config = lib.mkIf config.games.enable {
    home.packages = with pkgs; [
      steam
      r2modman
      # minecraft
      # prismlauncher
      # flashpoint
      ryujinx
      cemu
      # wii u usb helper
    ];
  };
}
