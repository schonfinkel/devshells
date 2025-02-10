# treefmt.nix
{ pkgs, ... }:
{
  # Used to find the project root
  projectRootFile = "flake.nix";
  programs = {
    mix-format.enable = true;
    nixfmt.enable = true;
    sqlfluff = {
      enable = true;
      dialect = "postgres";
    };
  };
}
