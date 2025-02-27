{pkgs, config, ...}:
{
  home.packages = with pkgs;[
    arduino
    arduino-cli
    kdePackages.ghostwriter
  ];
}
