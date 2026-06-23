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

    eca = {
      globalAgentsFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = ./eca/AGENTS.md;
        defaultText = lib.literalExpression "./eca/AGENTS.md";
        description = ''
          A markdown file installed as `~/.config/eca/AGENTS.md`. ECA
          auto-loads this file as context for every chat in every project,
          which means you don't have to drop a per-repo `AGENTS.md` /
          `CLAUDE.md` everywhere just for personal preferences. Set to
          `null` to disable.
        '';
      };

      rulesDir = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = ./eca/rules;
        defaultText = lib.literalExpression "./eca/rules";
        description = ''
          Directory of `*.md` rule files installed under
          `~/.config/eca/rules/`. Rules are smaller, focused instruction
          snippets that ECA can pull in. Set to `null` to disable.
        '';
      };

      commandsDir = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = ./eca/commands;
        defaultText = lib.literalExpression "./eca/commands";
        description = ''
          Directory of `*.md` custom slash-command prompts installed under
          `~/.config/eca/commands/`. Each `foo.md` becomes a `/foo`
          command in ECA chat. Set to `null` to disable.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    programs.emacs = {
      enable = true;
      package = cfg.package;
      extraPackages = emacsLib.emacsPackagesWithConfig;
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

    # Ship ECA's global agent context (AGENTS.md), rules and commands
    # directly from the flake, so every project automatically gets the same
    # baseline instructions without a per-repo CLAUDE.md / AGENTS.md.
    xdg.configFile = lib.mkMerge [
      (lib.mkIf (cfg.eca.globalAgentsFile != null) {
        "eca/AGENTS.md".source = cfg.eca.globalAgentsFile;
      })
      (lib.mkIf (cfg.eca.rulesDir != null) {
        "eca/rules" = {
          source = cfg.eca.rulesDir;
          recursive = true;
        };
      })
      (lib.mkIf (cfg.eca.commandsDir != null) {
        "eca/commands" = {
          source = cfg.eca.commandsDir;
          recursive = true;
        };
      })
    ];
  };
}
