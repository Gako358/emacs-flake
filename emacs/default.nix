{ bivrost, mugge }:
{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.programs.merrinx-emacs;
  emacsLib = import ./lib.nix {
    inherit pkgs bivrost;
    muggeSrc = mugge;
  };

  ecaHooks = import ./eca/hooks.nix { inherit pkgs; };

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
      defaultText = lib.literalExpression "pkgs.emacs31";
      description = "The base Emacs package to build the configuration on.";
    };

    defaultEditor = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to set the Emacs client as the default editor (EDITOR).";
    };

    minimal.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to install the `emacs-minimal` launcher on PATH. It starts a
        fast, standalone terminal Emacs (`-nw`) built from a curated subset of
        this configuration (base settings, evil, theme and modeline), with its
        own state directory so it never touches your main Emacs config. Handy
        as a `vim`/`vi` replacement for quick edits.
      '';
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
          `CLAUDE.md` everywhere just for personal preferences. Custom agents
          are configured separately with `eca.agentsDir`. Set to `null` to
          disable.
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

      agentsDir = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = ./eca/agents;
        defaultText = lib.literalExpression "./eca/agents";
        description = ''
          Directory of `*.md` custom agent and subagent definitions installed
          under `~/.config/eca/agents/`. Set to `null` to disable.
        '';
      };

      settings = lib.mkOption {
        type = lib.types.nullOr (lib.types.attrsOf lib.types.anything);
        default = {
          defaultAgent = "lead";
          toolCall.approval = {
            byDefault = "ask";
            allow = {
              eca__shell_command.argsMatchers.command = [
                "^nix flake check[^;&|<>`$()]*$"
                "^nix build( [^-][^;&|<>`$()]*)?$"
                "^nix eval( [^-][^;&|<>`$()]*)?$"
                "^nix develop(?!.*\\s(-c|--command)\\s)[^;&|<>`$()]*$"
                "^nix develop[^;&|<>`$()]*\\s(-c|--command)\\s(sbt|sbtn|scalafmt|scalafix|cargo|pytest|ruff|black|npm|pnpm|yarn|mvn|\\./mvnw|make)[^;&|<>`$()]*$"
                "^nix fmt[^;&|<>`$()]*$"
                "^(sbt|sbtn) (compile|test|testQuick|scalafmtCheckAll|scalafixAll( --check)?)[^;&|<>`$()]*$"
                "^(sbt|sbtn) [a-zA-Z0-9._-]+/(compile|test|testQuick|scalafmtCheckAll|scalafixAll( --check)?)[^;&|<>`$()]*$"
                "^scalafmt --check[^;&|<>`$()]*$"
                "^scalafix --check[^;&|<>`$()]*$"
                "^cargo (test|clippy|check|build|fmt)[^;&|<>`$()]*$"
                "^mvn (verify|test|compile)[^;&|<>`$()]*$"
                "^./mvnw (verify|test|compile)[^;&|<>`$()]*$"
                "^pytest[^;&|<>`$()]*$"
                "^ruff (check|format --check)[^;&|<>`$()]*$"
                "^black --check[^;&|<>`$()]*$"
                "^npm run (test|typecheck|lint|build|check)[^;&|<>`$()]*$"
                "^pnpm (test|typecheck|lint|build|check)[^;&|<>`$()]*$"
                "^yarn (test|typecheck|lint|build|check)[^;&|<>`$()]*$"
                "^npx (tsc|vue-tsc|eslint|vitest)[^;&|<>`$()]*$"
                "^git (status|diff|log|show|rev-parse)[^;&|<>`$()]*$"
              ];
              eca__git.argsMatchers.command = [
                "^git (status|diff|log|show|rev-parse)[^;&|<>`$()]*$"
                "^gh (pr|issue|run) (view|diff|list)[^;&|<>`$()]*$"
              ];
            };
            deny = {
              eca__shell_command.argsMatchers.command = [
                ".*\\bgit\\s+(?:(?:-C\\s+[^;&|<>`$()\\s]+|-c\\s+[^;&|<>`$()\\s]+|--git-dir(?:=|\\s+)[^;&|<>`$()\\s]+|--work-tree(?:=|\\s+)[^;&|<>`$()\\s]+)\\s+)*(?:add|commit|push|tag|merge|rebase|reset|restore|rm|mv|cherry-pick|revert|notes|submodule(?:\\s+(?:add|deinit|update))?)\\b.*"
                ".*\\bgit\\s+(?:(?:-C\\s+[^;&|<>`$()\\s]+|-c\\s+[^;&|<>`$()\\s]+|--git-dir(?:=|\\s+)[^;&|<>`$()\\s]+|--work-tree(?:=|\\s+)[^;&|<>`$()\\s]+)\\s+)*(?:clean\\s+-f|branch\\s+-D|checkout\\s+(?:--|-b|-B)|switch\\s+-[cC]|stash\\s+(?:push|pop|apply|drop|clear)|worktree\\s+(?:add|remove|move|prune))\\b.*"
                ".*\\bgh\\s+pr\\s+(?:create|merge)\\b.*"
                ".*\\bgh\\s+release\\s+create\\b.*"
                ".*\\bnix\\b.*--(?:impure|expr)\\b.*"
              ];
              eca__git.argsMatchers.command = [
                ".*\\bgit\\s+(?:(?:-C\\s+[^;&|<>`$()\\s]+|-c\\s+[^;&|<>`$()\\s]+|--git-dir(?:=|\\s+)[^;&|<>`$()\\s]+|--work-tree(?:=|\\s+)[^;&|<>`$()\\s]+)\\s+)*(?:add|commit|push|tag|merge|rebase|reset|restore|rm|mv|cherry-pick|revert|notes|submodule(?:\\s+(?:add|deinit|update))?)\\b.*"
                ".*\\bgit\\s+(?:(?:-C\\s+[^;&|<>`$()\\s]+|-c\\s+[^;&|<>`$()\\s]+|--git-dir(?:=|\\s+)[^;&|<>`$()\\s]+|--work-tree(?:=|\\s+)[^;&|<>`$()\\s]+)\\s+)*(?:clean\\s+-f|branch\\s+-D|checkout\\s+(?:--|-b|-B)|switch\\s+-[cC]|stash\\s+(?:push|pop|apply|drop|clear)|worktree\\s+(?:add|remove|move|prune))\\b.*"
                ".*\\bgh\\s+pr\\s+(?:create|merge)\\b.*"
                ".*\\bgh\\s+release\\s+create\\b.*"
              ];
            };
          };
          hooks = {
            lead-workflow-gate = {
              type = "preToolCall";
              matcher = "eca__spawn_agent";
              visible = false;
              description = "Architect invocation is hook-proven; lead waits for its populated register and tracker readback";
              actions = [
                {
                  type = "shell";
                  file = "${ecaHooks.gate}/bin/eca-lead-workflow-gate";
                }
              ];
            };
            lead-workflow-record = {
              type = "postToolCall";
              matcher = "eca__spawn_agent";
              visible = false;
              description = "Track which subagents ran in a lead chat";
              actions = [
                {
                  type = "shell";
                  file = "${ecaHooks.record}/bin/eca-lead-workflow-record";
                }
              ];
            };
            lead-workflow-verify = {
              type = "postRequest";
              visible = false;
              description = "Force a verification turn after implementation subagents ran";
              actions = [
                {
                  type = "shell";
                  file = "${ecaHooks.verify}/bin/eca-lead-workflow-verify";
                }
              ];
            };
          };
        };
        description = ''
          Attribute set serialized to `~/.config/eca/config.json`. Notably
          `defaultAgent` decides which primary agent new chats start with;
          the custom subagents in `eca.agentsDir` are restricted via
          `spawnableBy` and are only discoverable from that agent. The
          default `hooks` enforce the lead workflow server-side: no
          implementation subagent may be spawned before the architect hook
          proves invocation, while the lead waits for the architect's returned
          populated register and tracker readback; a turn where implementation
          subagents ran is followed by a forced verification turn. The default
          `toolCall.approval` block auto-allows read-only/verification
          shell commands and hard-denies staging, commits, and destructive git
          operations regardless of agent. Hooks prove invocation prerequisites
          only; lead waits for populated register/tracker readback and reports
          actual gate outcomes.
          Set to `null` to not manage the file.
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

      skillsDir = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = ./eca/skills;
        defaultText = lib.literalExpression "./eca/skills";
        description = ''
          Directory of reusable ECA skills installed under
          `~/.config/eca/skills/`. Set to `null` to disable.
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
      ]
      ++ lib.optional cfg.minimal.enable (
        pkgs.writeShellScriptBin "emacs-minimal" ''
          export PATH="${fullPath}"
          dir="''${XDG_CONFIG_HOME:-$HOME/.config}/emacs-minimal"
          mkdir -p "$dir"
          exec ${emacsLib.emacsMinimal}/bin/emacs --init-directory="$dir" -nw "$@"
        ''
      );
    };

    # Ship ECA's global agent context (AGENTS.md), agents, rules, commands and
    # skills directly from the flake, so every project automatically gets the
    # same baseline instructions without a per-repo CLAUDE.md / AGENTS.md.
    xdg.configFile = lib.mkMerge [
      (lib.mkIf (cfg.eca.globalAgentsFile != null) {
        "eca/AGENTS.md".source = cfg.eca.globalAgentsFile;
      })
      (lib.mkIf (cfg.eca.settings != null) {
        "eca/config.json".text = builtins.toJSON cfg.eca.settings;
      })
      (lib.mkIf (cfg.eca.agentsDir != null) {
        "eca/agents" = {
          source = cfg.eca.agentsDir;
          recursive = true;
        };
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
      (lib.mkIf (cfg.eca.skillsDir != null) {
        "eca/skills" = {
          source = cfg.eca.skillsDir;
          recursive = true;
        };
      })
    ];
  };
}
