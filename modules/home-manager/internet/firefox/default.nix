{config,lib, pkgs, inputs, ...}:
{
  imports = [
    ./main.nix
    # ./school.nix
    # ./old-personal.nix
  ];

  
  config = {
    programs.firefox = {
      enable = config.gui.enable;
      # policies = [
      
      # ];   

    };
  };
}
