# Nix Devshells

- [Nix Devshells](#nix-devshells)
  - [Projects](#projects)
    - [Language-Based Environments](#language-based-environments)
      - [Elixir](#elixir)
      - [F#](#f)
      - [Gleam](#gleam)
      - [OCaml](#ocaml)
    - [Tooling](#tooling)
      - [PostgreSQL](#postgresql)
    - [FOSS Development](#foss-development)
      - [Terrateam](#terrateam)

These are my personal devshells, lots of opinionated tools, you always free to change and adapt it. I've created this repo to make bootstraping my own nix-based projects faster.

## Projects

### Language-Based Environments

#### Elixir

```shell
nix flake new --template github:schonfinkel/devshells#gleam ./dir
```

#### F\#

```shell
nix flake new --template github:schonfinkel/devshells#fsharp ./dir
```

#### Gleam

```shell
nix flake new --template github:schonfinkel/devshells#gleam ./dir
```

#### OCaml

```shell
nix flake new --template github:schonfinkel/devshells#ocaml ./dir
```

### Tooling

#### PostgreSQL

This spawns a generic `postgresql.nix` with a pre-configured PG database for local usage. As to replace docker compose completelly.

```shell
nix flake new --template github:schonfinkel/devshells#postgresql .
```

### FOSS Development

#### Terrateam

```shell
nix flake new --template github:schonfinkel/devshells#terrateam .
```
