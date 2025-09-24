{
  description = "An Elixir development environment";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";

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
          # nix develop --impure
          default = devenv.lib.mkShell {
            inherit inputs pkgs;
            modules = [
              (
                { pkgs, lib, ... }:
                {
                  packages = [];

                  languages.elixir = {
                    enable = true;
                  };

                  enterShell = ''
                    echo "Starting Development Environment..."
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
                      session_preload_libraries = "auto_explain";
                      "auto_explain.log_min_duration" = 150;
                      "auto_explain.log_analyze" = true;
                      log_min_duration_statement = 0;
                      log_statement = "all";
                      log_directory = "log";
                      log_filename = "postgresql-%Y-%m-%d.log";
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
