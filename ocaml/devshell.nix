{ pkgs, tooling ? [], ... }:
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
}
