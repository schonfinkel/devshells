{
  description = "F# Development Environment";

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

        dotnet =
          with pkgs.dotnetCorePackages;
          combinePackages [
            sdk_8_0
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
            netcoredbg
            fsautocomplete
            fantomas
          ]
          ++ pkgs.lib.optionals pkgs.stdenv.isLinux linuxPkgs
          ++ pkgs.lib.optionals pkgs.stdenv.isLinux darwinPkgs;

        app_name = "app";
        app_version = "0.1.0";
      in
      {
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
      }
    );
}
