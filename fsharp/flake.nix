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

        tooling = with pkgs; [
          bash
          just

          # for PG
          icu
          inotify-tools

          # for dotnet
          netcoredbg
          fsautocomplete
          fantomas
        ];

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
      }
    );
}
