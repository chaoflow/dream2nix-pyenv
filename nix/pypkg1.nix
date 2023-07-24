{
  config,
  lib,
  dream2nix,
  ...
}: let
  l = lib // builtins;
in {
  name = "pypkg1";
}
