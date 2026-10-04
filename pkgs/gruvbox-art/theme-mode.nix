# theme-mode: live toggle between stylix's gruvbox and gruvbox-art for the
# current painting. See theme_mode.py's docstring for what it reaches.
{
  lib,
  writers,
  writeShellScriptBin,
  callPackage,
  hyprland,
  libnotify,
  glib,
  procps,
  systemd,
  noctalia ? null,
  # obsidian-cli for the snippet reload, and the vault names to reload.
  obsidianCli ? null,
  obsidianVaults ? [ ],
  # base16 YAML of the scheme stylix is using (gruvbox mode).
  gruvboxScheme,
  # Directory with current.json naming the painting (art-wallpaper's layout).
  artDir,
}:
let
  gruvboxArt = callPackage ./. { };
  script = writers.writePython3 "theme-mode" {
    flakeIgnore = [ "E501" ];
  } (builtins.readFile ./theme_mode.py);
in
writeShellScriptBin "theme-mode" ''
  export PATH=${
    lib.makeBinPath (
      [
        hyprland
        libnotify
        glib # gdbus, for the ghostty reload
        procps
        systemd
      ]
      ++ lib.optional (noctalia != null) noctalia
    )
  }:$PATH
  export THEME_MODE_GRUVBOX=${gruvboxScheme}
  export THEME_MODE_ART_DIR=${artDir}
  export THEME_MODE_GRUVBOX_ART=${lib.getExe gruvboxArt}
  # Upstream's ghostty reload: systemd unit, then D-Bus action, then SIGUSR2.
  export THEME_MODE_GHOSTTY_RELOAD=${
    if noctalia != null then
      "${noctalia}/share/noctalia/assets/templates/ghostty/reload.sh"
    else
      "/dev/null"
  }
  ${lib.optionalString (obsidianCli != null) ''
    export THEME_MODE_OBSIDIAN_CLI=${obsidianCli}
    export THEME_MODE_OBSIDIAN_VAULTS=${lib.escapeShellArg (builtins.toJSON obsidianVaults)}
  ''}
  exec ${script} "$@"
''
