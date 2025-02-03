{pkgs,config, lib, ...}:
let
cfg = config.search;
in
{

  "Nix Packages" = lib.mkIf cfg.nix-search.enable{
  # "Nix Packages" = {
    urls = [{
      template = "https://search.nixos.org/packages";
      params = [
        { name = "type"; value = "packages"; }
        { name = "query"; value = "{searchTerms}"; }
      ];
    }];

    icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
    definedAliases = [ "@np" ];
  };

    # "cargo" = lib.mkIf cfg.cargo.enable {
    #   urls = [{
    #     template = "https://crates.io/crates/search";
    #     params = [
    #       { name = "type"; value = "packages"; }
    #       { name = "query"; value = "{searchTerms}"; }
    #     ];
    #   }];

    #   # icon = ""

    # };
    
}
