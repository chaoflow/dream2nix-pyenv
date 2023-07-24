# NOTE: Move into top-level subdirectory to have all nix tooling in one place?
{
  config,
  lib,
  dream2nix,
  ...
}: let
  l = lib // builtins;
in {
  imports = [
    dream2nix.modules.drv-parts.pip
  ];

  version = "1";

  mkDerivation = {
    # NOTE: Should be taken from pyproject.toml [build-sytem].
    nativeBuildInputs = [
      config.deps.setuptools
    ];
  };

  buildPythonPackage = {
    format = "pyproject";
  };

  pip = {
    pypiSnapshotDate = "2023-07-24";
  };
}
