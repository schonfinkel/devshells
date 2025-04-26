{
  description = "Terrateam Development Environment";

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
          pkg-config
        ];

        darwinPkgs = with pkgs.darwin.apple_sdk.frameworks; [
          CoreFoundation
          CoreServices
        ];

        libreTLS =
          pkgs.stdenv.mkDerivation (finalAttrs: {
            pname = "libretls";
            version = "3.8.1";
          
            src = pkgs.fetchgit {
              url = "https://git.causal.agency/libretls";
              tag = finalAttrs.version;
              hash = "sha256-cFu9v8vOkfvIj/OfD0Er3n+gbH1h1CHOHA6a0pJuwXY=";
            };
          
            nativeBuildInputs = with pkgs; [
              pkg-config
              autoreconfHook
              libtool
            ];

            # https://git.causal.agency/libretls/about/
            autoreconfFlags = [
              "--force"
              "--install"
            ];
          
            buildInputs = with pkgs; [ openssl ];
          
            strictDeps = true;
          });

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
            ngrok
            nodejs_23
            opam
            sqlite
            yj
            zlib
          ])
          ++ [ libreTLS ]
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
