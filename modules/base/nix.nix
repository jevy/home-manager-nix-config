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
          connect-timeout = 5;
          fallback = true;
          extra-substituters = [
            "https://hyprland.cachix.org"
            "https://nix-community.cachix.org"
          ];
          extra-trusted-public-keys = [
            "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
            "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
          ];
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
