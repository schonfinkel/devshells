# treefmt.nix
{ pkgs, ... }:
{
  # Used to find the project root
  projectRootFile = "flake.nix";
  programs = {
    # ocamlformat.enable = true;
    nixfmt.enable = true;
    sqlfluff = {
      enable = true;
      dialect = "postgres";
    };
    shfmt.enable = true;
  };
}
