{ pkgs, tooling, app_name }:
{
  packages = tooling;

  scripts = {
    build.exec = "make -j12 -k release_terrat";
    pg-test.exec = "make -j12 -k release_pgsql_test_client debug_pgsql_test_client";
  };

  enterShell = ''
    echo "Starting Development Environment..."
    ./setup.sh
    eval $(opam env --switch=5.1.1)
  '';

  services.postgres = {
    enable = true;
    package = pkgs.postgresql_17;
    extensions = ext: [
      ext.periods
      ext.pg_cron
    ];
    initdbArgs = [
      "--locale=C"
      "--encoding=UTF8"
    ];
    hbaConf = builtins.readFile ./pg_hba.conf;
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
      { name = app_name; user = app_name; pass = app_name; }
    ];
    port = 5432;
    listen_addresses = "127.0.0.1";
    initialScript = ''
      CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
      CREATE ROLE postgres WITH SUPERUSER LOGIN PASSWORD 'postgres';
      CREATE ROLE test_user LOGIN PASSWORD 'postgres';
      ALTER DATABASE ${app_name} OWNER TO postgres;
    '';
  };
}
