{pkgs, inputs, ...}:
{
  imports = [
    ./main.nix
    # ./school.nix
    # ./old-personal.nix
  ];

  programs.firefox = {
    enable = true;
    # policies = [
      
    # ];   

  };
}
