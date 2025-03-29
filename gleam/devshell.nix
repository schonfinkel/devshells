{ pkgs, tooling ? [], ... }:
{
  packages = tooling;

  languages.gleam = {
    enable = true;
  };

  scripts = {
    build.exec = "just build";
    db-up.exec = "just db-up";
    db-down.exec = "just db-down";
    db-reset.exec = "just db-reset";
  };

  enterShell = ''
    echo "Starting Development Environment..."
  '';
}
