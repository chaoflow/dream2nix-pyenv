{
  # NOTE: Is flake-utils still the way to go?
  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.dream2nix.url = "github:nix-community/dream2nix/flo-hack";

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    dream2nix,
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};
        l = nixpkgs.lib // builtins;

        python = pkgs.python310;

        setupModule = {config, ...}: {
          imports = [
            dream2nix.modules.drv-parts.pip
          ];

          lock.repoRoot = ./.;
          lock.lockFileRel = "/nix/${config.name}-${config.deps.stdenv.system}-lock.json";

          deps = {nixpkgs, ...}: {
            inherit (nixpkgs)
              stdenv
              ;
            # NOTE: Is it good to inherit python here instead of using nixpkgs.python310?
            inherit python;
            setuptools = nixpkgs.python310Packages.setuptools;
          };

          # NOTE: This version has no meaning for the setup.
          version = "1";

          mkDerivation = {
            src = "../code/${config.name}";

            nativeBuildInputs = [
              config.deps.setuptools
            ];
          };

          buildPythonPackage = {
            format = "pyproject";
          };

          pip = {
            # NOTE: It would be nice to optionally passed via CLI, defaulting to today.
            pypiSnapshotDate = "2023-07-25";
            requirementsFiles = [
              "code/${config.name}/requirements-dev.txt"
            ];
          };
        };

        callModule = module:
          dream2nix.lib.evalModules {
            packageSets = {
              nixpkgs = pkgs;
            };
            modules = [
              module
              setupModule
            ];
          };

        pypkg1 = callModule ./nix/pypkg1.nix;
        pypkg2 = callModule ./nix/pypkg2.nix;

        pythonDeps =
          pypkg1.config.mkDerivation.propagatedBuildInputs ++
          pypkg2.config.mkDerivation.propagatedBuildInputs ++
          (with python.pkgs; [
            # pip
            # setuptools
            wheel
            tkinter
          ]);
        pyenv = python.withPackages (packages: pythonDeps);

      in {
        devShell = pkgs.mkShell {
          SITEPACKAGES = pyenv.out + "/" + pyenv.sitePackages;

          packages = [
            pyenv
          ] ++ (with pkgs; [
            nodejs_20
          ]);

          shellHook = ''
            export REPOROOT="$(realpath .)"
            export DIRENVPY="$REPOROOT/.direnv/python-${pyenv.pythonVersion}"
            export DIRENVPY_SITEPACKAGES="$DIRENVPY/${pyenv.sitePackages}"
            if ! [ -e "$DIRENVPY" ]; then
              echo "Setting up $DIRENVPY ..."
              ${pyenv.interpreter} -m venv "$DIRENVPY"
              for path in "$SITEPACKAGES"/*; do
                if ! [ -e "$DIRENVPY_SITEPACKAGES/$(basename "$path")" ]; then
                  ln -sL -t "$DIRENVPY_SITEPACKAGES" $path
                fi
              done

              # Additional dev tools, causing problems via d2n because of pip/setuptools dependency.
              "$DIRENVPY/bin/python" -m pip install \
                pip-tools \
                setuptools-scm

              # Dev install of our packages.
              "$DIRENVPY/bin/python" -m pip install \
                --disable-pip-version-check \
                --no-index \
                --no-build-isolation \
                -e "$REPOROOT/code/pypkg1" \
                -e "$REPOROOT/code/pypkg2"

              # Some commands need to run with the python interpreter of our venv.
              for cmd in mypy ruff ruff_lsp; do
                cat >"$DIRENVPY/bin/$cmd" <<EOF
          #!/bin/sh
          exec "$DIRENVPY/bin/python" -m $cmd "\$@"
          EOF
                chmod +x "$DIRENVPY/bin/$cmd"
              done
            fi
          '';
        };

        packages = {
          inherit
            pypkg1
            pypkg2
          ;
        };
      }
    );
}
