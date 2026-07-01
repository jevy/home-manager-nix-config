# Declarative Flatpak via nix-flatpak.
#
# Why Flatpak at all: Bambu Studio's nixpkgs build cannot load its proprietary
# network plugin (libbambu_networking.so) on NixOS — it crashes with
# "free(): invalid pointer", which kills printer discovery, login and LAN mode.
# See nixpkgs#498307 / #398019. The Flathub build ships the FHS-style runtime
# that blob expects, so it works. This host has no impermanence and a writable
# persistent btrfs root, so Flatpak's mutable state in /var/lib/flatpak is fine.
{ inputs, ... }:
{
  flake.modules.nixos.flatpak =
    { ... }:
    {
      imports = [ inputs.nix-flatpak.nixosModules.nix-flatpak ];

      services.flatpak = {
        enable = true;

        remotes = [
          {
            name = "flathub";
            location = "https://dl.flathub.org/repo/flathub.flatpakrepo";
          }
        ];

        packages = [
          "com.bambulab.BambuStudio"
        ];

        # Leave installed-but-undeclared apps alone — don't nuke anything added
        # by hand. And don't pull updates during `rebuildhm`, so an offline
        # rebuild never hangs/fails on a network fetch (the managed-install
        # service already needs network on first switch to grab the runtime).
        uninstallUnmanaged = false;
        update.onActivation = false;
      };
    };
}
