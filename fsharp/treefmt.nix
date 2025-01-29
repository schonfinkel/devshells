# treefmt.nix
{ pkgs, ... }:
{
  # Used to find the project root
  projectRootFile = "flake.nix";
  programs = {
    fantomas.enable = true;
    nixfmt.enable = true;
    sqlfluff = {
      enable = true;
      dialect = "postgres";
    };
  };
}
