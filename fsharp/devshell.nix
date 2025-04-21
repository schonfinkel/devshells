{
  pkgs,
  dotnet,
  tooling ? [ ],
  app_name,
  ...
}:
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
