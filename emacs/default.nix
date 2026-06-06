{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.programs.merrinx-emacs;
  emacsLib = import ./lib.nix { inherit pkgs; };

  # PATH segments the Emacs server and the `ec` client should see.
  systemToolsPath = "/run/current-system/sw/bin";
  wrappersPath = "/run/wrappers/bin";
  homeManagerPath = "/etc/profiles/per-user/${config.home.username}/bin";

  fullPath = "${emacsLib.emacsOnlyPath}:${wrappersPath}:${systemToolsPath}:${homeManagerPath}:$PATH";
in
{
  options.programs.merrinx-emacs = {
    enable = lib.mkEnableOption "MerrinX's Emacs (editor, server and client)";

    package = lib.mkOption {
      type = lib.types.package;
      default = emacsLib.emacsBase;
      defaultText = lib.literalexpression "pkgs.emacs30";
      description = "The base Emacs package to build the configuration on.";
    };

    defaultEditor = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to set the Emacs client as the default editor (EDITOR).";
    };

    persistence = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to register impermanence persistence directories used by
        Emacs (ECA cache, GitHub Copilot config). Only takes effect when the
        impermanence home-manager module is also imported by the consumer.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    programs.emacs = {
      enable = true;
      package = cfg.package;
      extraPackages = emacsLib.emacsPackagesFn;
      extraConfig = emacsLib.extraConfig;
    };

    # Emacs server (daemon) + client integration.
    services.emacs = {
      enable = true;
      client.enable = true;
      defaultEditor = cfg.defaultEditor;
      socketActivation.enable = true;
    };

    # Ensure the Emacs server sees all the language tooling on PATH.
    systemd.user.services.emacs = {
      Service = {
        Environment = [
          "PATH=${fullPath}"
        ];
      };
    };

    home = {
      persistence = lib.mkIf cfg.persistence {
        "/persist/" = {
          directories = [
            ".cache/eca"
            ".config/github-copilot"
          ];
        };
      };

      packages = [
        (pkgs.writeShellScriptBin "ec" ''
          export PATH="${fullPath}"
          exec ${cfg.package}/bin/emacsclient "$@"
        '')
      ];
    };
  };
}
