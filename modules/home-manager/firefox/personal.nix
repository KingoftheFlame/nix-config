{pkgs, config, inputs, lib, ...} :
{
  search.nix-search.enable = true;

  programs.firefox.profiles.matthew = {
    search = {
      force = true;
      default = "Google";
      engines = import ./search.nix {pkgs = pkgs; config = config; lib = lib;};
    };

    extensions = with inputs.firefox-addons.packages."x86_64-linux";[
      ublock-origin
      sponsorblock
      youtube-shorts-block
      privacy-badger
      tab-stash
      indie-wiki-buddy
    ];

    settings = {
      
    };

    bookmarks = [
     #toolbar
     {
      name = "toolbar";
      toolbar = true;
      bookmarks = [

        {
          name = "messaging";
          bookmarks = [
             {
              name = "messages";
              tags = ["messaging"];
              url = "https://messages.google.com/web/conversations";
            }

            {
              name = "instagram chats";
              tags = ["messaging"];
              url = "https://www.instagram.com/direct/inbox/";
            }   
          ];
        }        

        {
          name = "bandcamp";
          url = "bandcamp.com";
        }

        {
          name = "github";
          url = "github.com";
        }

        {
          name = "cloudflare";
          url = "https://dash.cloudflare.com/";
        } 
     ];} 
      
    ];
    
  };
}
