{
  description = "Terrateam Development Environment";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    flake-utils = {
      url = "github:numtide/flake-utils/v1.0.0";
    };

    opam-nix.url = "github:tweag/opam-nix";

    devenv = {
      url = "github:cachix/devenv";
      inputs.nixpkgs.follows = "nixpkgs";
    };

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
      flake-utils,
      opam-nix,
      treefmt-nix,
      ...
    }@inputs:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
          };
        };

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

        treefmtEval = treefmt-nix.lib.evalModule pkgs ./treefmt.nix;

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
            ngrok
            nodejs
            opam
            sqlite
            yj
            zlib
          ])
          ++ pkgs.lib.optionals pkgs.stdenv.isLinux linuxPkgs
          ++ pkgs.lib.optionals pkgs.stdenv.isLinux darwinPkgs;
      in
      {
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
      }
    );
}
