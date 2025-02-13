{pkgs, inputs, ...}:
{
  imports = [
    # ./personal.nix
    # ./school.nix
    # ./old-personal.nix
  ];

  programs.firefox = {
    enable = true;
    # policies = [
      
    # ];   

  };
}
