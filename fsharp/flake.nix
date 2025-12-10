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
          dotnet = pkgs.dotnet-sdk_10;
          linuxPkgs = with pkgs; [
            icu
            inotify-tools
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
              buildInputs = tooling ++ [ dotnet ];
            };

            # nix develop --impure
            default = devenv.lib.mkShell {
              inherit inputs pkgs;
              modules = [
                (
                  { pkgs, lib, ... }:
                  {
                    packages = tooling;

                    languages.dotnet = {
                      enable = true;
                      package = dotnet;
                    };

                    scripts = {
                      build.exec = "just build";
                      db-up.exec = "just db-up";
                      db-down.exec = "just db-down";
                      db-reset.exec = "just db-reset";
                    };

                    enterShell = ''
                      echo "Starting Development Environment..."
                      dotnet --version
                    '';

                    services.postgres = {
                      enable = true;
                      package = pkgs.postgresql_17;
                      extensions = ext: [
                        ext.periods
                      ];
                      initdbArgs = [
                        "--locale=C"
                        "--encoding=UTF8"
                      ];
                      settings = {
                        shared_preload_libraries = "pg_stat_statements";
                        # pg_stat_statements config, nested attr sets need to be
                        # converted to strings, otherwise postgresql.conf fails
                        # to be generated.
                        compute_query_id = "on";
                        "pg_stat_statements.max" = 10000;
                        "pg_stat_statements.track" = "all";
                      };
                      initialDatabases = [ { name = app_name; } ];
                      port = 5432;
                      listen_addresses = "127.0.0.1";
                      initialScript = ''
                        CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
                        CREATE USER admin SUPERUSER;
                        ALTER USER admin PASSWORD 'admin';
                        GRANT ALL PRIVILEGES ON DATABASE ${app_name} to admin;
                      '';
                    };
                  }
                )
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
