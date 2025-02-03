# Add your reusable home-manager modules to this directory, on their own file (https://nixos.wiki/wiki/Module).
# These should be stuff you would like to share with others, not your personal configurations.
{
  # List your module files here
  # my-module = import ./my-module.nix;

  options = import ./options.nix;

  #terminal
  terminal = import ./terminal;
  neovim = import ./neovim;

  wsl = import ./wsl.nix;

  games = import ./games.nix;
  music = import ./music.nix;
  internet = import ./internet.nix;
  firefox = import ./firefox;

  sci-tools = import ./sci-tools.nix;
}
