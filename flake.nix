{
  description = "Jevin's Home Manager configuration";

  inputs = {
    # ─────────────────────────────────────────────────────────────────────────
    # When bumping `nixpkgs`, bump `nixvim` in lockstep (its nixos-render-docs
    # patch goes stale and fails to apply against a newer nixpkgs).
    #
    # HISTORY (2026-07-27): nixpkgs 26.11 made evaluating x86_64-darwin a hard
    # throw. That briefly broke our eval — NOT via home-manager as first
    # suspected, but via bun2nix (pulled in by `hunk` and `pi-mono`): its
    # nixpkgs follows ours, and building its packages forces its flake-parts
    # `perSystem` for every system in its `systems` input, which defaulted to
    # nix-systems/default (includes x86_64-darwin). Fixed consumer-side by
    # pointing those `systems` inputs at nix-systems/triplet (see the
    # `nix-systems-triplet` input and the follows on hunk/pi-mono below).
    # ─────────────────────────────────────────────────────────────────────────
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager/master";

    # macOS system management (mac-work host). Runs with nix.enable = false —
    # Nix itself is owned by the Determinate nix-installer here, so nix-darwin
    # manages the system (and the /Applications/Nix Apps Spotlight aliaser)
    # without touching the Nix installation. See modules/hosts/mac-work.
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Dendritic pattern infrastructure
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    import-tree.url = "github:vic/import-tree";

    nixos-hardware.url = "github:NixOS/nixos-hardware";
    # Upstream stylix (release 26.11, matches this system). The neomutt theming
    # the old mputz86/neomutt fork provided is reimplemented in modules/apps/mutt.nix
    # as a small home-manager module sourcing a base16-rendered muttrc, so no fork
    # is needed — see that file and modules/apps/base16-stylix.muttrc.mustache.
    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    neomutt-gmail = {
      url = "github:jevy/neomutt-for-gmail";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    spicetify-nix.url = "github:Gerg-L/spicetify-nix";
    sops-nix.url = "github:Mic92/sops-nix";
    deploy-rs.url = "github:serokell/deploy-rs";
    deploy-rs.inputs.nixpkgs.follows = "nixpkgs";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    mcp-servers-nix = {
      url = "github:natsukium/mcp-servers-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hunk = {
      url = "github:modem-dev/hunk";
      inputs.nixpkgs.follows = "nixpkgs";
      # See x86_64-darwin note at the top of `inputs`
      inputs.bun2nix.inputs.systems.follows = "nix-systems-triplet";
    };
    nix-systems-triplet.url = "github:nix-systems/triplet";

    # herdr — terminal workspace manager for AI coding agents. Not in nixpkgs;
    # upstream's flake exposes packages only (no home-manager module), so
    # modules/dev/herdr.nix wires it up by hand.
    herdr = {
      url = "github:herdrdev/herdr";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # tuicr — PR review TUI (a herdr-pickr reviewer backend, also useful alone).
    tuicr = {
      url = "github:agavra/tuicr";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # herdr-pickr — herdr plugin: Ctrl+click a PR/MR link → pick a reviewer.
    # A plain script directory (bash + a TOML manifest), not a flake.
    herdr-pickr = {
      url = "github:tomasvarga/herdr-pickr";
      flake = false;
    };
    # herdr-hunk — herdr plugin: an fzf picker that opens any diff (working
    # tree, staged, a commit, a range, a stash) in a hunk pane. A plain script
    # directory (bash + a TOML manifest) with no build hook at all, so
    # pkgs/herdr-hunk.nix just stages it. Replaced herdr-reviewr — see the
    # "Why hunk, not reviewr" note in modules/dev/herdr.nix.
    #
    # Unpinned: upstream ships no tags (0.1.1 lives only in the manifest), so
    # there is nothing to pin to. `nix flake update herdr-hunk` moves it.
    herdr-hunk = {
      url = "github:JacquesvanWyk/herdr-hunk";
      flake = false;
    };
    hyprland = {
      # Bumped 0.53.1 → 0.55.4: ashell 0.9.0 requires the `tiledLayout` field in
      # Hyprland's workspace IPC, which only exists from 0.54+ (layout-engine
      # redesign). Without it the workspace indicator silently disappears.
      url = "github:hyprwm/Hyprland/v0.55.4";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hy3 = {
      # Must track the Hyprland minor for plugin ABI compatibility.
      url = "github:outfoxxed/hy3/hl0.55.0";
      inputs.hyprland.follows = "hyprland";
    };
    hyprland-plugins = {
      url = "github:hyprwm/hyprland-plugins";
      inputs.hyprland.follows = "hyprland";
    };
    typing-analysis = {
      url = "github:jevy/typing-analysis";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    typestream = {
      url = "github:typestreamio/typestream/v0.3.6";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pi-mono.url = "github:lukasl-dev/pi-mono.nix";
    # See x86_64-darwin note at the top of `inputs`
    pi-mono.inputs.bun2nix.inputs.systems.follows = "nix-systems-triplet";

    # Declarative Flatpak app management. Needed for Bambu Studio: the nixpkgs
    # build crashes loading the proprietary libbambu_networking.so plugin
    # (free(): invalid pointer), so printer discovery/login never works. The
    # Flathub build runs in an FHS-like sandbox where that blob loads cleanly.
    nix-flatpak.url = "github:gmodena/nix-flatpak";

};

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ (inputs.import-tree ./modules) ];
    };
}
