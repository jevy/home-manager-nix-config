{
  description = "Jevin's Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager/master";

    # Pinned to the last nixpkgs whose linuxPackages_latest is kernel 7.0.6 — used
    # ONLY for boot.kernelPackages on lenovo-p14s. Kernel 7.1 reworked the mt7925
    # MLO / station-teardown path (RCU wcid lifetime), which races the NAPI RX
    # poll and re-inits a poll_list it already linked → list_add corruption
    # hard-locks under network load (kernel BUG at lib/list_debug.c:32 in
    # mt7925_mac_add_txs, Comm napi/phy0-0). 7.0.6 predates that rework — proven
    # crash-free ~26 days on this machine — AND predates the 7.0.7 BT break, so it
    # has working BT + no wifi crash. The upstream fix (torvalds 20b126920a25) is
    # only in mainline v7.2-rc1, unreleased and with no stable backport tag.
    # TODO: drop this input + restore linuxPackages_latest once a release carries
    # the fix (v7.2, est. late Aug 2026). See modules/hardware/lenovo-p14s.nix.
    nixpkgs-kernel706.url = "github:NixOS/nixpkgs/ec5490bc79b6e20068bfb068d572a05678bed4f4";

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
    llmfit = {
      url = "github:AlexsJones/llmfit";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    lieer-src.url = "path:/home/jevin/src/lieer";
    lieer-src.flake = false;
    pi-mono.url = "github:lukasl-dev/pi-mono.nix";

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
