{
  description = "MerrinX's Emacs — editor, server and client as a reusable home-manager module";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      flake = {
        homeModules.emacs = ./emacs;
        homeModules.default = ./emacs;
      };

      perSystem =
        { pkgs, system, ... }:
        let
          emacsLib = import ./emacs/lib.nix { inherit pkgs; };

          testEmacs = pkgs.writeShellScriptBin "test-emacs" ''
            set -euo pipefail
            tmp="$(mktemp -d)"
            trap 'rm -rf "$tmp"' EXIT
            echo "Launching configured Emacs with HOME=$tmp" >&2
            HOME="$tmp" \
            XDG_CONFIG_HOME="$tmp/.config" \
            XDG_CACHE_HOME="$tmp/.cache" \
            XDG_DATA_HOME="$tmp/.local/share" \
              exec ${emacsLib.emacsWithConfig}/bin/emacs "$@"
          '';
        in
        {
          packages = {
            default = emacsLib.emacsWithConfig;
            emacs = emacsLib.emacsWithConfig;
            config = emacsLib.configEl;
            config-compiled = emacsLib.configPackage;
          };

          apps = {
            default = {
              type = "app";
              program = "${testEmacs}/bin/test-emacs";
            };
            test = {
              type = "app";
              program = "${testEmacs}/bin/test-emacs";
            };
          };

          devShells.default = pkgs.mkShell {
            name = "emacs-flake";
            packages = [
              emacsLib.emacsWithConfig
              testEmacs
            ]
            ++ emacsLib.emacsOnlyTools;
            shellHook = ''
              echo "emacs-flake dev shell"
              echo "  test-emacs        launch the configured Emacs in a sandboxed HOME"
              echo "  emacs             the configured Emacs (uses your real HOME!)"
            '';
          };

          checks = {
            emacs = emacsLib.emacsWithConfig;
            config-compiles = emacsLib.configPackage;
          };
        };
    };
}
