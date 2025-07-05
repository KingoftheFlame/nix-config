{pkgs, config, ...}:

let shared-extensions =
  with pkgs.vscode-extensions;[
    bbenoist.nix
  ]
  ++ pkgs.vscode-utils.extensionsFromVscodeMarketplace [
  {
    name = "vscode-helix-emulation";
    publisher = "jasew";
    version = "0.6.3";
    sha256 = "iHPAFzo1sJI+TMk0pzkuOPw2pTo7g44cZd1EWIifHyM=";
  }
];

in
{
  config = {
    programs.vscode = {
      enable = !config.is-wsl;
      # profiles.default.extensions = with pkgs.vscode-extensions; [
        # dracula-theme.theme-dracula
        # vscodevim.vim
        # yzhang.markdown-all-in-one
      # ] ++ shared-shared-extensions;


      profiles.cpp = {
        extensions = with pkgs.vscode-extensions;[
          ms-vscode.cpptools
          jdinhlife.gruvbox
          rust-lang.rust-analyzer
          mhutchie.git-graph
        ] ++ pkgs.vscode-utils.extensionsFromVscodeMarketplace[
          {
            name = "Arduino";
            publisher = "moozzyk";
            version = "0.0.4";
            sha256 = "/xAl4wLwQ6DJy2IKd6vSrVcY8w8OKwfRXboEk9VKs2o=";
          }
        ] ++ shared-extensions;
            
      };
    };
  };
}
