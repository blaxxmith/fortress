{
  description = "A simple password manager written in Rust";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    treefmt = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs:
    inputs.parts.lib.mkFlake {inherit inputs;} {
      systems = ["x86_64-linux" "aarch64-linux" "aarch64-darwin"];

      imports = [inputs.treefmt.flakeModule];

      perSystem = {pkgs, ...}: {
        packages.default = let
          manifest = (pkgs.lib.importTOML ./Cargo.toml).package;
        in
          pkgs.rustPlatform.buildRustPackage {
            pname = manifest.name;
            version = manifest.version;
            cargoLock.lockFile = ./Cargo.lock;
            src = pkgs.lib.cleanSource ./.;

            meta = {
              description = manifest.description;
              homepage = manifest.repository;
              maintainers = manifest.authors;
              mainProgram = "frtrs";
            };
          };

        devShells.default = pkgs.mkShell {
          name = "rust";
          packages = with pkgs; [
            bacon
            cargo
            cargo-audit
            cargo-tarpaulin
            rust-analyzer
            wrkflw
          ];
        };

        treefmt.config = {
          projectRootFile = "flake.nix";
          flakeCheck = true;
          programs = {
            alejandra.enable = true;
            rustfmt.enable = true;
            prettier.enable = true;
          };
        };
      };
    };
}
