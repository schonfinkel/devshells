{
  description = "F# Development Environment";

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
      ];
      perSystem =
        { pkgs, system, ... }:
        let
          dotnet =
            with pkgs.dotnetCorePackages;
            combinePackages [
              sdk_10_0
            ];

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
              just

              # for dotnet
              fsautocomplete
              fantomas
            ]
            ++ pkgs.lib.optionals pkgs.stdenv.isLinux linuxPkgs;

          app_name = "app";
          app_version = "0.1.0";
          treefmtEval = treefmt-nix.lib.evalModule pkgs ./treefmt.nix;
        in
        {
          # This sets `pkgs` to a nixpkgs with allowUnfree option set.
          _module.args.pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };

          # nix build
          packages = rec {
            devenv-up = self.devShells.${system}.default.config.procfileScript;

            # `nix build`
            default = pkgs.buildDotnetModule {
              pname = app_name;
              version = app_version;
              src = ./.;
              projectFile = "src/App/App.fsproj";
              nugetDeps = ./deps.json;
              dotnet-sdk = dotnet;
              dotnet-runtime = dotnet;
            };

            # nix build .#dockerImage
            dockerImage = pkgs.dockerTools.buildLayeredImage {
              name = app_name;
              tag = app_version;
              created = "now";
              contents = [ default ];
              config = {
                Cmd = [
                  "${default}/bin/App"
                ];
              };
            };
          };

          # Shells
          devShells = {
            # nix develop .#ci
            # reduce the number of packages to the bare minimum needed for CI
            ci = pkgs.mkShell {
              buildInputs = dotnet ++ tooling;
            };

            # nix develop --impure
            default = devenv.lib.mkShell {
              inherit inputs pkgs;
              modules = [
                (import ./devshell.nix {
                  inherit
                    pkgs
                    dotnet
                    tooling
                    app_name
                    ;
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
