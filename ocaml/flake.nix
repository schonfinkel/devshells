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
          ]
          ++ pkgs.lib.optionals pkgs.stdenv.isLinux linuxPkgs
          ++ pkgs.lib.optionals pkgs.stdenv.isLinux darwinPkgs;

        app_name = "app";
      in
      {
        # nix build
        packages = rec {
          devenv-up = self.devShells.${system}.default.config.procfileScript;

          # `nix build`
          # ...
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
              (
                { pkgs, lib, ... }:
                {
                  packages = tooling;

                  languages.ocaml = {
                    enable = true;
                  };

                  scripts = {
                    build.exec = "dune build";
                    watch.exec = "dune build --watch";
                  };

                  enterShell = ''
                    echo "Starting Development Environment..."
                    dune --version
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
                    initialDatabases = [ 
                      { name = app_name; }
                      { name = "postgres"; user = "postgres" }
                    ];
                    port = 5432;
                    listen_addresses = "127.0.0.1";
                    initialScript = ''
                      CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
                      CREATE ROLE postgres SUPERUSER;
                      CREATE USER admin SUPERUSER;
                      ALTER USER admin PASSWORD 'admin';
                      ALTER USER postgres PASSWORD 'postgres';
                      GRANT ALL PRIVILEGES ON DATABASE ${app_name} to admin;
                      GRANT ALL PRIVILEGES ON DATABASE ${app_name} to postgres;
                      GRANT ALL PRIVILEGES ON DATABASE postgres to postgres;
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
