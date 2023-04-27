To run the config:
`sudo nixos-rebuild switch --flake .#`

This flake will look at the hostname to determine which derivation to build.

## For Mac

`home-manager switch`

For font to install and stuff:
1. Delete the p10k config dir
2. Run `p10k configure`, and it just does the right thing.
