# tuicr — terminal PR review TUI (comments go back to the forge). Not in
# nixpkgs, so it comes from upstream's flake (naersk-built Rust, all four
# unix systems). Useful standalone (`tuicr pr <url>`) and doubles as the
# default reviewer backend for herdr-pickr — see modules/dev/herdr.nix.
{ inputs, ... }:
{
  flake.modules.homeManager.tuicr =
    { pkgs, ... }:
    {
      home.packages = [ inputs.tuicr.packages.${pkgs.stdenv.hostPlatform.system}.default ];
    };
}
