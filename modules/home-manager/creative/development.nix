{pkgs, config, ...}:
{
  home.packages = with pkgs;[
    # arduino
    # arduino-cli
    arduino-ide
    kdePackages.ghostwriter
  
  ];

  programs.vscode = {
    enable = true;
    package = pkgs.vscodium;
   profiles.default.extensions = with pkgs.vscode-extensions; [
      # dracula-theme.theme-dracula
      # vscodevim.vim
      yzhang.markdown-all-in-one
    ];
  };
  
}
