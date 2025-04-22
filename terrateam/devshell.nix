{ pkgs, tooling, app_name }:
{
  packages = tooling ++ [ pkgs.python3 ];

  scripts = {
    build.exec = "make -j$(nproc --all) -k release_terrat";
    release.exec = "make -j$(nproc --all) release_terrat_oss";
    server.exec = "./build/release/terrat_oss/terrat_oss.native server";
    pg-build.exec = "make -j$(nproc --all) -k release_pgsql_test_client debug_pgsql_test_client";
    pg-test.exec = "./build/debug/pgsql_test_client/pgsql_test_client.native 127.0.0.1 terrateam terrateam terrateam";
    pg-con.exec = "psql -h 127.0.0.1 -p 5432 -U terrateam terrateam";
  };

  env = {
    NGROK_ENDPOINT = "http://ngrok:4040";
    DB_HOST = "127.0.0.1";
    DB_PORT = "5432";
    DB_USER = "terrateam";
    DB_PASS = "terrateam";
    DB_NAME = "terrateam";
    TERRAT_API_BASE="https://terrateam.example.com";
    TERRAT_PYTHON_EXEC="${pkgs.python3}/bin/python3";
  };

  enterShell = ''
    echo "Starting Development Environment..."
    eval $(opam env --switch=5.1.1)
    opam switch show
  '';

  #services.nginx = {
  #  enable = true;
  #};

  dotenv = {
    enable = true;
    filename = ".env";
  };

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
