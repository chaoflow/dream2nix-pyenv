# NOTE: Move into top-level subdirectory to have all nix tooling in one place?
{
  config,
  lib,
  dream2nix,
  ...
}: let
  l = lib // builtins;
in {
  name = "pypkg2";
}
