{config, pkgs, inputs, lib, ...}:
{
  options = with lib;{
    gui.enable = mkEnableOption "Enable GUI applications";
  };
}


