{host, ...}: let
  vars = import ../../hosts/${host}/variables.nix;
  inherit
    (vars)
    alacrittyEnable
    ghosttyEnable
    waybarChoice
    vscodeEnable
    helixEnable
    ;
  # Select bar module based on barChoice
  barModule = waybarChoice;
in {
  imports =
    [
      ./amfora.nix
      ./bash.nix
      ./bashrc-personal.nix
      ./overview.nix
      ./python.nix
      ./cli/bat.nix
      ./cli/btop.nix
      ./cli/bottom.nix
      ./cli/cava.nix
      ./emoji.nix
      ./eza.nix
      ./fastfetch
      ./cli/fzf.nix
      ./cli/gh.nix
      ./cli/git.nix
      ./gtk.nix
      ./cli/htop.nix
      ./hyprland
      ./terminals/kitty.nix
      ./cli/lazygit.nix
      ./obs-studio.nix
      #./editors/nvf.nix
      ./editors/nixvim.nix
      ./editors/nano.nix
      ./rofi
      ./qt.nix
      ./scripts
      ./scripts/gemini-cli.nix
      ./stylix.nix
      ./swappy.nix
      ./swaync.nix
      ./tealdeer.nix
      ./virtmanager.nix
      barModule
      ./wlogout
      ./xdg.nix
      ./yazi
      ./zen-browser.nix
      ./zoxide.nix
      ./zsh
    ]
    ++ (
      if helixEnable
      then [./editors/evil-helix.nix]
      else []
    )
    ++ (
      if vscodeEnable
      then [./editors/vscode.nix]
      else []
    ) ++ (
      if ghosttyEnable
      then [./terminals/ghostty.nix]
      else []
    )a++ (
      if alacrittyEnable
      then [./terminals/alacritty.nix]
      else []
    );
}
