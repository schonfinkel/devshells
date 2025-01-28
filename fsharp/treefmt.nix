# treefmt.nix
{ pkgs, ... }:
{
  # Used to find the project root
  projectRootFile = "flake.nix";
  programs = {
    dotnet.enable = true;
    nixfmt.enable = true;
  };
}
