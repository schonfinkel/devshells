{
  devenv,
  pkgs,
  tooling,
}:

let
  databases = [
    {
      name = "terrateam";
      user = "terrateam";
      pass = "terrateam";
    }
  ];
  pwd = builtins.getEnv "PWD";
  mainRepo = builtins.getEnv "MAIN_REPO";
  terrat_api_url = builtins.getEnv "TERRAT_API_URL";
  terrat_ui_base = builtins.getEnv "https://${terrat_api_url}/";
  assetsSuffix = "build/debug/iris/dist";
  assetsPath = "${mainRepo}/code/${assetsSuffix}";
in
{
  packages =
    tooling
    ++ [
      pkgs.liburing
      pkgs.python3
    ];

  scripts = {
    build.exec = "make -j$(nproc --all) .merlin terrat";
    build_s.exec = "make .merlin terrat";
    build_schema.exec = "make -j$(nproc --all) -k .merlin terrat-schemas";
    format_schema.exec = "jq -S . < config-schema.json > /tmp/config-schema.json; mv /tmp/config-schema.json ./";
    migrate.exec = "./build/debug/terrat_$TERRAT_EDITION/terrat_$TERRAT_EDITION.native migrate --verbosity=debug";
    server.exec = ''
      migrate
      ./build/debug/terrat_$TERRAT_EDITION/terrat_$TERRAT_EDITION.native server --verbosity=debug
    '';
    release.exec = "make -j$(nproc --all) release_terrat_oss";
    ttm.exec = "${mainRepo}/code/build/debug/ttm/ttm.native";
    pg-build.exec = "make -j$(nproc --all) -k release_pgsql_test_client debug_pgsql_test_client";
    pg-test.exec = "./build/debug/pgsql_test_client/pgsql_test_client.native $DB_HOST $DB_NAME $DB_USER $DB_PASS";
    pg-con.exec = "psql -h $DB_HOST -p $DB_PORT -U $DB_USER $DB_NAME";
  };

  env = {
    DB_HOST = "127.0.0.1";
    DB_PORT = "5432";
    DB_USER = "terrateam";
    DB_PASS = "terrateam";
    DB_NAME = "terrateam";
    DB_CONNECT_TIMEOUT = "10";
    # Static Nix crap
    # LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath staticLibs}:$LD_LIBRARY_PATH";
    # Ensure pkg-config can find the libraries
    # PKG_CONFIG_PATH = "${pkgs.openssl.dev}/lib/pkgconfig:${pkgs.zlib.dev}/lib/pkgconfig";
    # Add library paths for static linking
    # NIX_LDFLAGS = [
    #   "-L${pkgs.pkgsStatic.curl.out}/lib"
    #   "-L${pkgs.glibc.static}/lib"
    #   "-L${pkgs.pkgsStatic.openssl.out}/lib"
    #   "-L${pkgs.zlib.static}/lib"
    # ];
    # Other Vars
    OCAMLRUNPARAM = "b";
    OPAMROOT = "${pwd}/.opam";
    TERRAT_EDITION = "ee";
    TERRAT_PYTHON_EXEC = "${pkgs.python3}/bin/python3";
    TERRAT_TELEMETRY_LEVEL = "disabled";
    TERRAT_STATEMENT_TIMEOUT = "1s";
    TERRAT_TMP_PATH = "/tmp/terrat";
  };

  enterShell = ''
    echo "Starting Development Environment..."
    export NIX_LDFLAGS="-L${pkgs.glibc}/lib $NIX_LDFLAGS"
    eval $(opam env --switch=5.3.0)
  '';

  languages.rust = {
    enable = true;
    # https://devenv.sh/reference/options/#languagesrustchannel
    channel = "stable";
  };

  processes = {
    tunnel.exec = "docker container run -e TERRATUNNEL_API_KEY=$TERRATUNNEL_API_KEY --network host ghcr.io/terrateamio/terratunnel:latest client --local-endpoint http://127.0.0.1:8000";
  };

  services.nginx = {
    enable = true;
    httpConfig = ''
      default_type  application/octet-stream;
      types_hash_bucket_size 128;
      sendfile        on;

      gzip  on;

      # tell nginx to use the real client ip for all CIDRs
      real_ip_header X-Forwarded-For;
      set_real_ip_from 0.0.0.0/0;

      keepalive_timeout 600;
      limit_conn_zone $server_name zone=terrat_app:10m;
      limit_req_zone $binary_remote_addr zone=client_limit:10m rate=1000r/s;

      client_body_buffer_size 64k;

      # Public facing portion of the app
      server {
          listen       8000;

          server_name  localhost;
          access_log   off;
          server_tokens off;

          location / {
              set $cspNonce '$request_id';
              sub_filter_once off;
              sub_filter_types *;
              sub_filter 'NGINX_CSP_NONCE' '$cspNonce';

              root ${assetsPath};
              index index.html index.htm;
              try_files $uri $uri/ /index.html;
              add_header Content-Security-Policy "default-src 'self' https://*.posthog.com; img-src 'self' https://avatars.githubusercontent.com; script-src 'self' 'nonce-$cspNonce' https://*.posthog.com; style-src 'self'; object-src 'none'; connect-src 'self' https://*.posthog.com";
          }

          location /assets {
              root ${assetsPath};
              tcp_nodelay on;
          }

          location /api {
              # Limit the proxy to a lower number of concurrent requests to keep
              # the underlying application happy.
              limit_conn terrat_app 3000;
              limit_req zone=client_limit burst=5000;

              proxy_pass http://127.0.0.1:8080;
              proxy_set_header X-Forwarded-For $remote_addr;
              proxy_set_header X-Forwarded-Base "${terrat_ui_base}";

              # Needed for returning response with large number of headers
              proxy_buffer_size 128k;
              proxy_buffers 4 256k;
              proxy_busy_buffers_size 256k;

              # This is the limit of how large we of input we allow.
              client_max_body_size 50m;

              # Add a long timeout to match the timeouts on the server side.
              proxy_read_timeout 120;
          }

          # Turn off rate limit for health checks
          location /health {
              proxy_pass http://127.0.0.1:8080;
              proxy_set_header X-Forwarded-For $remote_addr;
          }

          location /nginx_status {
              stub_status on;
              access_log off;
              allow ::1;
              allow 127.0.0.1;
              allow 172.17.0.0/24;
              deny all;
          }
      }
    '';
  };

  services.postgres = {
    enable = true;
    package = pkgs.postgresql_18;
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
      # SSL
      #ssl = "on";
      #ssl_cert_file = builtins.toString ./server.crt;
      #ssl_key_file = builtins.toString ./server.key;
      #ssl_ca_file = builtins.toString ./root.crt;
    }
    // pkgs.lib.optionalAttrs pkgs.stdenv.isLinux {
      max_connections = 200;
      # Async IO, io_uring or workers
      # For io_uring method (Linux only, requires liburing)
      io_method = "io_uring";
      # Adjust shared buffers
      shared_buffers = "2GB";
      # Increase work memory for large operations
      work_mem = "16MB";
      # Enable huge pages if available
      huge_pages = "try";
      # Adjust I/O concurrency settings
      effective_io_concurrency = 16;
      maintenance_io_concurrency = 16;
    };

    initialDatabases = databases;
    port = 5432;
    listen_addresses = "127.0.0.1";
    initialScript = ''
      CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
      CREATE ROLE postgres WITH SUPERUSER LOGIN PASSWORD 'postgres';
      CREATE ROLE mbenevides WITH SUPERUSER LOGIN;
      GRANT ALL PRIVILEGES ON DATABASE terrateam TO terrateam;
      GRANT ALL ON SCHEMA public TO terrateam;
      ALTER DATABASE terrateam OWNER TO terrateam;
    '';
  };
}
