# Nix settings for NixOS and home-manager
{ ... }:
{
  # NixOS Nix settings
  flake.modules.nixos.nix =
    { ... }:
    {
      nix = {
        extraOptions = ''
          experimental-features = nix-command flakes
        '';
        settings = {
          trusted-users = [
            "root"
            "jevin"
          ];
          download-buffer-size = 268435456;
          auto-optimise-store = true;
        };
        gc = {
          automatic = true;
          dates = "weekly";
          options = "--delete-older-than 30d";
        };
      };
    };

  # Home-manager Nix settings (for standalone macOS)
  flake.modules.homeManager.nix =
    { ... }:
    {
      nix.gc = {
        automatic = true;
        frequency = "weekly";
        options = "--delete-generations +8";
      };
    };
}
