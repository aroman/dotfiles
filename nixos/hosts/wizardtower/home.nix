{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    ../../modules/home.nix
  ];

  home.packages = with pkgs; [
    discord
    slack
  ];
}
