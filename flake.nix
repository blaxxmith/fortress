{
  description = "A simple password manager written in Rust";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    crane.url = "github:ipetkov/crane";

    parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    treefmt = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    fenix = {
      url = "github:nix-community/fenix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        rust-analyzer-src.follows = "";
      };
    };
  };

  outputs = inputs:
    inputs.parts.lib.mkFlake {inherit inputs;} {
      systems = ["x86_64-linux" "aarch64-linux" "aarch64-darwin"];
      imports = [inputs.treefmt.flakeModule];

      perSystem = {
        inputs',
        pkgs,
        ...
      }: let
        pname = "fortress";
        manifest = (pkgs.lib.importTOML ./Cargo.toml).package;
        nativeBuildInputs = with pkgs; [pkg-config openssl];
        rust = inputs'.fenix.packages.toolchainOf {
          channel = manifest.rust-version;
          sha256 = "sha256-MFHoWVcPZKjFrLnQnodCXbUsfZcofGfo9tV9fTTvklg=";
        };
        toolchain = inputs'.fenix.packages.combine (with rust; [cargo rustc clippy rustfmt llvm-tools]);

        craneLib = (inputs.crane.mkLib pkgs).overrideToolchain toolchain;
        cargoArtifacts = craneLib.buildDepsOnly commonArgs;
        src = craneLib.cleanCargoSource ./.;

        binary = craneLib.buildPackage commonArgs;

        commonArgs = {
          inherit src cargoArtifacts nativeBuildInputs pname;
          inherit (manifest) version;
          strictDeps = true;
          doCheck = false;
          meta = {
            inherit (manifest) description;
            homepage = manifest.repository;
            maintainers = manifest.authors;
            mainProgram = "frtrs";
          };
        };
      in {
        checks = {
          inherit binary;
          clippy = craneLib.cargoClippy (commonArgs // {cargoClippyExtraArgs = "--all-targets --workspace -- -D warnings";});
          fmt = craneLib.cargoFmt commonArgs;
        };

        packages.default = binary;

        devShells.default = pkgs.mkShell {
          name = "rust";
          inherit nativeBuildInputs;
          packages = with pkgs; [cargo-audit bacon cargo-nextest cargo-llvm-cov] ++ [toolchain];
          shellHook = ''
            echo "Rust DevShell. Versions:"
            echo "- $(rustc --version)"
            echo "- $(cargo --version)"
          '';
        };

        treefmt.config = {
          projectRootFile = "flake.nix";
          flakeCheck = true;
          programs = {
            alejandra.enable = true;
            deadnix.enable = true;
            statix.enable = true;
            prettier.enable = true;
            taplo.enable = true;
          };
        };
      };
    };
}
