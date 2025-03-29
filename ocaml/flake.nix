{
  description = "OCaml Development Environment";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    flake-utils = {
      url = "github:numtide/flake-utils/v1.0.0";
    };

    devenv = {
      url = "github:cachix/devenv";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    treefmt-nix.url = "github:numtide/treefmt-nix";
  };

  outputs =
    {
      self,
      nixpkgs,
      devenv,
      flake-utils,
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

        treefmtEval = treefmt-nix.lib.evalModule pkgs ./treefmt.nix;

        linuxPkgs = with pkgs; [
          icu
          inotify-tools
        ];

        darwinPkgs = with pkgs.darwin.apple_sdk.frameworks; [
          CoreFoundation
          CoreServices
        ];

        tooling =
          with pkgs;
          [
            bash
            fswatch
            gnumake
            opam
          ]
          ++ pkgs.lib.optionals pkgs.stdenv.isLinux linuxPkgs
          ++ pkgs.lib.optionals pkgs.stdenv.isLinux darwinPkgs;

        _app_name = "app";
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
            buildInputs = tooling ++ [pkgs.ocaml];
          };

          # nix develop --impure
          default = devenv.lib.mkShell {
            inherit inputs pkgs;
            modules = [
              (import ./devshell.nix {
                inherit pkgs tooling;
              })
            ];
          };
        };

        # nix fmt
        formatter = treefmtEval.config.build.wrapper;
      }
    );
}
