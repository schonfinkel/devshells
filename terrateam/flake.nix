{
  description = "Terrateam Development Environment";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    devenv = {
      url = "github:cachix/devenv";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
    };

    opam-nix.url = "github:tweag/opam-nix";

    treefmt-nix.url = "github:numtide/treefmt-nix";

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs = { nixpkgs.follows = "nixpkgs"; };
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      devenv,
      flake-parts,
      opam-nix,
      treefmt-nix,
      ...
    }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      perSystem =
        { pkgs, system, ... }:
        let
          on = opam-nix.lib.${system};
          # Local packages, detected from the package definition files in `./opam/`.
          localPackagesQuery =
            let
              opam-lib = opam-nix.lib.${system};
            in
            pkgs.lib.mapAttrs (_: pkgs.lib.last)
              (opam-lib.listRepo (opam-lib.makeOpamRepo ./.));

          # Development package versions.
          devPackagesQuery = {
            ocaml-lsp-server = "*";
            ocamlformat = "*";
            utop = "*";
          };

          # Development package versions, along with the base compiler tools, used
          # when building the opam project with `opam-nix`.
          allPackagesQuery = devPackagesQuery // {
            # # Use the OCaml compiler from nixpkgs
            # ocaml-system = "*";
            # Use OCaml compiler from opam-repository
            ocaml-base-compiler = "5.3.0";
          };

          linuxPkgs = with pkgs; [
            icu
            inotify-tools
            pkg-config
          ];

          darwinPkgs = with pkgs.darwin.apple_sdk.frameworks; [
          ];
          
          tooling =
            (with pkgs; [
              bash
              clang
              curl
              fswatch
              glibcLocales
              gnumake
              gmp
              libffi
              libkqueue
              libpq
              libretls
              postgresql
              nodejs
              opam
              sqlite
              yj
              zlib
            ])
            ++ pkgs.lib.optionals pkgs.stdenv.isLinux linuxPkgs
            ++ pkgs.lib.optionals pkgs.stdenv.isLinux darwinPkgs;

          treefmtEval = treefmt-nix.lib.evalModule pkgs ./treefmt.nix;
        in
      {
        # This sets `pkgs` to a nixpkgs with allowUnfree option set.
        _module.args.pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

        # nix build
        packages = {
          devenv-up = self.devShells.${system}.default.config.procfileScript;
        };

        # Shells
        devShells = {
          # nix develop .#ci
          # reduce the number of packages to the bare minimum needed for CI
          ci = pkgs.mkShell {
            buildInputs = tooling;
          };

          # nix develop --impure
          default = devenv.lib.mkShell {
            inherit inputs pkgs;
            modules = [
              (import ./devshell.nix { 
                inherit devenv pkgs tooling;
              })
            ];
          };

        };

        # nix fmt
        formatter = treefmtEval.config.build.wrapper;
      };

      flake = {
      };
  };
}
