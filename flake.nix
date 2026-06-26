{
  description = "Jevin's Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager/master";

    # Pinned to the last nixpkgs whose linuxPackages_latest is kernel 7.0.6 — the
    # newest 7.0.x that dodges BOTH recent regressions:
    #   - 7.0.7 regressed MT7925/MT7922 Bluetooth: btmtk rejects the chip's short
    #     WMT FUNC_CTRL event ("Failed to send wmt func ctrl (-22)", no controller).
    #     Introduced by 634a4408c061, fixed in 7.0.10 by e193447ac6c9.
    #   - 7.0.9 regressed pidfd→/proc mapping, breaking xdg-desktop-portal app-info
    #     resolution (all GTK4/portal file pickers fail: "Unable to open
    #     /proc/<pid>/root" — Save As in Papers, file uploads in Slack, etc).
    # 7.0.7/7.0.8 fix the portal but break BT; 7.0.10 fixes BT but breaks the
    # portal. 7.0.6 predates both. Used only for boot.kernelPackages on lenovo-p14s.
    # See modules/hardware/lenovo-p14s.nix.
    # TODO: drop this input and restore linuxPackages_latest once a kernel ships
    # with both the btmtk fix and the portal/pidfd fix. Track:
    #   https://github.com/flatpak/xdg-desktop-portal/issues/1653
    #   https://github.com/flatpak/xdg-desktop-portal/issues/1719
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
      url = "github:hyprwm/Hyprland/v0.53.1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hy3 = {
      url = "github:outfoxxed/hy3/hl0.53.0";
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

};

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ (inputs.import-tree ./modules) ];
    };
}
