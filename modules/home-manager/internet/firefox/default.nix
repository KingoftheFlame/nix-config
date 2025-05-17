{config,lib, pkgs, inputs, ...}:
{
  imports = [
    ./main.nix
    # ./school.nix
    # ./old-personal.nix
  ];

  
  config = {
    programs.firefox = {
      enable = lib.mkIf config.gui.enable;
      # policies = [
      
      # ];   

    };
  };
}
