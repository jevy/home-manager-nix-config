{
  outputs = { self, nixpkgs }: {

    packages.x86_64-linux.muttdown = nixpkgs.legacyPackages.x86_64-linux.callPackage ./derivation.nix {};

    packages.x86_64-linux.default = self.packages.x86_64-linux.muttdown;

  };
}
