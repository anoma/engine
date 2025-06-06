{
  description = "Anoma Engine";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
  #inputs.nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  inputs.utils.url = "github:numtide/flake-utils";

  outputs = {
    self,
    nixpkgs,
    utils,
  }:
    utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs rec {inherit system;};
        epkgs = pkgs.beam.packages.erlang;
      in rec {
        packages = with pkgs; rec {
          engine = beamPackages.mixRelease {
            pname = "anoma-engine";
            version = "0.1.0";
            src = ./.;
            removeCookie = false;
            mixNixDeps = with pkgs;
              import ./deps.nix {
                inherit lib beamPackages;
                overrides = self: super: {
                  #foo = beamPackages.buildMix {
                  #  name = "foobar";
                  #  version = "1.0.0";
                  #  src = fetchTree {
                  #    type = "github";
                  #    owner = "bar";
                  #    repo = "foobar";
                  #    rev = "4e63e01ffcdfe5f4ca135fe84886c795e96259ae3";
                  #  };
                  #  beamDeps = [ ... ];
                  #};
                };
              };
          };

          default = engine;
        };

        apps = rec {
          engine = utils.lib.mkApp {
            drv = packages.engine;
            exePath = "/bin/engine_system";
          };
          default = engine;
        };

        devShell = pkgs.mkShell {
          buildInputs = with pkgs; [
            epkgs.elixir
            epkgs.hex
            glibcLocales
            mix2nix
            livebook
          ];
        };
      }
    );
}
