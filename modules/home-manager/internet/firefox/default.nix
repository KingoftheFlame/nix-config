{config,lib, pkgs, inputs, ...}:
{
  imports = [
    # ./main.nix
    # ./school.nix
    # ./old-personal.nix
  ];

  
  config = {
    home.packages = [
      pkgs.firefox-devedition
    ];
  };
}
