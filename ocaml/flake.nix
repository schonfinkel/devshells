{
  description = "OCaml Development Environment";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    devenv = {
      url = "github:cachix/devenv";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
    };

    treefmt-nix.url = "github:numtide/treefmt-nix";
  };

  outputs =
    {
      self,
      nixpkgs,
      devenv,
      flake-parts,
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
          treefmtEval = treefmt-nix.lib.evalModule pkgs ./treefmt.nix;
          app_name = "app";
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
      };

      flake = {
      };
  };
}
