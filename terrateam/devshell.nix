{ devenv, pkgs, tooling }:

let
  databases = [
    { name = "terrateam"; user = "terrateam"; pass = "terrateam"; }
  ];
in
{
  packages = tooling ++ [ pkgs.python3 ];

  scripts = {
    build.exec = "make -j$(nproc --all) -k release_terrat";
    release.exec = "make -j$(nproc --all) release_terrat_oss";
    server.exec = "./build/release/terrat_oss/terrat_oss.native server";
    pg-build.exec = "make -j$(nproc --all) -k release_pgsql_test_client debug_pgsql_test_client";
    pg-test.exec = "./build/debug/pgsql_test_client/pgsql_test_client.native 127.0.0.1 terrateam terrateam terrateam";
    pg-con.exec = "psql -h 127.0.0.1 -p 5432 -U terrateam terrateam";
    pg-ssl.exec = "psql 'host=127.0.0.1 dbname=terrateam user=terrateam sslmode=verify-ca sslcert=client.crt sslkey=client.key sslrootcert=root.crt'";
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
      # SSL
      #ssl = "on";
      #ssl_cert_file = builtins.toString ./server.crt;
      #ssl_key_file = builtins.toString ./server.key;
      #ssl_ca_file = builtins.toString ./root.crt;
    };
    initialDatabases = databases;
    port = 5432;
    listen_addresses = "127.0.0.1";
    initialScript = ''
      CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
      CREATE ROLE postgres WITH SUPERUSER LOGIN PASSWORD 'postgres';
      ALTER DATABASE terrateam OWNER TO postgres;
    '';
  };
}
