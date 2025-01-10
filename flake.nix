{
  description = "A collection of flake templates";

  outputs = { self }: {
    # nix flake new --template templates#<flake> ./dir
    templates = {
      fsharp = {
        path = ./fsharp;
        description = "A basic web app template for F#";
        welcomeText = ''
          # Getting started
          - Run `nix develop --impure`
        '';
      };

      gleam = {
        path = ./gleam;
        description = "A basic web app template for Gleam + Postgres";
        welcomeText = ''
          # Getting started
          - Run `nix develop --impure`
        '';
      };
    };

    defaultTemplate = self.templates.gleam;
  };
}
