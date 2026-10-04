# Obsidian theming through stylix.targets.obsidian (Linux desktop).
#
# The target writes through home-manager's programs.obsidian: a "Stylix
# Config" CSS snippet plus fonts, into each vault in vaultNames. That makes
# the vault's .obsidian/appearance.json a read-only store symlink, so
# appearance changes made in Obsidian's settings no longer save; set them
# here instead. The first activation moves the hand-made appearance.json
# aside as appearance.json.backup (home-manager.backupFileExtension).
#
# Live art tint (Meta+D → c): desktop/wallpaper.nix adds a "theme-mode"
# snippet to the same vaults, symlinked to a file theme-mode rewrites.
{ ... }:
{
  flake.modules.homeManager.obsidian =
    { lib, ... }:
    {
      programs.obsidian = {
        enable = true;
        # desktop/apps.nix installs it, alongside everything else.
        package = null;

        vaults."Second Brain" = {
          target = "Second Brain Obsidian/Second Brain";
          settings.appearance = {
            # The stylix snippet styles .theme-dark only when stylix.polarity
            # is "dark"; ours is the default "either", so it writes
            # .theme-light and the vault has to stay in light mode.
            theme = "moonstone";
            # stylix's fonts.sizes.applications is points (12); Obsidian
            # reads px.
            baseFontSize = lib.mkForce 18;
          };
        };
      };

      # Upstream's activation merges a vault entry into
      # ~/.config/obsidian/obsidian.json keyed by md5(target). Obsidian
      # already knows this vault under its own id, so the merge would list
      # it twice, and it would write `cli = false` (cli.enable's default),
      # turning off the CLI the obsidian-notes skill uses. Obsidian keeps
      # managing obsidian.json itself.
      home.activation.obsidian = lib.mkForce (lib.hm.dag.entryAfter [ "writeBoundary" ] "");

      stylix.targets.obsidian.vaultNames = [ "Second Brain" ];
    };
}
