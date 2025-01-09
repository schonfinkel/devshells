{
  description = "A collection of flake templates";

  outputs = { self }: {

    templates = {
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
