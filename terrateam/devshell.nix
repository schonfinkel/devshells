{ devenv, pkgs, tooling }:

let
  databases = [
    { name = "terrateam"; user = "terrateam"; pass = "terrateam"; }
  ];
  pwd = builtins.getEnv "PWD";
  mainRepo = builtins.getEnv "MAIN_REPO";
  terrat_api_url = builtins.getEnv "TERRAT_API_URL";
  terrat_ui_base = builtins.getEnv "https://${terrat_api_url}/";
  assetsSuffix = "build/release/terrat_ui_files/assets";
  assetsPath = "${mainRepo}/code/${assetsSuffix}";
in
{
  packages = tooling ++ [ pkgs.python3 ];

  scripts = {
    build.exec = "make -j$(nproc --all) .merlin release_terrat_oss release_terrat_ee debug_terrat_oss debug_terrat_ee";
    build_s.exec = "make .merlin release_terrat_oss release_terrat_ee debug_terrat_oss debug_terrat_ee";
    build_schema.exec = "make -j$(nproc --all) -k .merlin terrat-schemas";
    format_schema.exec = "jq -S . < config-schema.json > /tmp/config-schema.json; mv /tmp/config-schema.json ./";
    migrate.exec = "./build/debug/terrat_$TERRAT_EDITION/terrat_$TERRAT_EDITION.native migrate --verbosity=debug";
    server.exec = ''
      migrate
      ./build/debug/terrat_$TERRAT_EDITION/terrat_$TERRAT_EDITION.native server --verbosity=debug
    '';
    release.exec = "make -j$(nproc --all) release_terrat_oss";
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
    DB_CONNECT_TIMEOUT="10";
    GITHUB_WEB_BASE_URL="https://github.com";
    NGROK_ENDPOINT = "http://ngrok:4040";
    OCAMLRUNPARAM="b";
    OPAMROOT = "${pwd}/.opam";
    TERRAT_EDITION="ee";
    TERRAT_PYTHON_EXEC="${pkgs.python3}/bin/python3";
    TERRAT_TELEMETRY_LEVEL="disabled";
    TERRAT_STATEMENT_TIMEOUT="1s";
    TERRAT_TMP_PATH="/tmp/terrat";
  };

  enterShell = ''
    echo "Starting Development Environment..."
    eval $(opam env --switch=5.3.0)
  '';

  languages.rust = {
    enable = true;
    # https://devenv.sh/reference/options/#languagesrustchannel
    channel = "stable";
  };

  processes = {
    ngrok.exec = "ngrok http --url=$TERRAT_API_URL --log=stdout 8080";
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

      keepalive_timeout  65;
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

              proxy_pass http://127.0.0.1:8180;
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
              proxy_pass http://127.0.0.1:8180;
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

          location /install {
              return 301 https://github.com/apps/terrateam-action;
          }

          location /install/github {
              return 301 https://github.com/apps/terrateam-action;
          }
      }
    '';
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
      GRANT ALL PRIVILEGES ON DATABASE terrateam TO terrateam;
      GRANT ALL ON SCHEMA public TO terrateam;
      ALTER DATABASE terrateam OWNER TO terrateam;
    '';
  };
}
