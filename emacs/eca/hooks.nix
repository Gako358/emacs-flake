{ pkgs }:
let
  # Agents that may only run once `architect` has returned a plan for the chat.
  implementationAgents = "backend|frontend|scala|java|refactorer|docs";

  stateSnippet = ''
    state_dir() {
      local root="''${XDG_RUNTIME_DIR:-/tmp}/eca-lead-workflow"
      printf '%s/%s/%s' "$root" "''${1//[^a-zA-Z0-9_-]/_}" "''${2//[^a-zA-Z0-9_-]/_}"
    }
  '';

  mkHook =
    name: text:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [
        pkgs.jq
        pkgs.coreutils
      ];
      text = stateSnippet + text;
    };
in
{
  gate = mkHook "eca-lead-workflow-gate" ''
    input=$(cat)

    if [ "$(jq -r '.agent // ""' <<< "$input")" != "lead" ]; then
      exit 0
    fi

    target=$(jq -r '.tool_input.agent // ""' <<< "$input")
    case "$target" in
      ${implementationAgents}) ;;
      verifier) ;;
      *) exit 0 ;;
    esac

    dir=$(state_dir "$(jq -r '.session_id // ""' <<< "$input")" \
                    "$(jq -r '.chat_id // ""' <<< "$input")")

    case "$target" in
      ${implementationAgents})
        if [ ! -e "$dir/architect" ]; then
          jq -n --arg agent "$target" \
            '{approval: "deny",
              additionalContext: ("Workflow gate: no architect plan exists for this chat yet. Spawn `architect` with the full task first, then delegate to `" + $agent + "` with the resulting plan."),
              systemMessage: ("Blocked spawn of `" + $agent + "`: architect plan required first.")}'
        fi
        ;;
      verifier)
        task=$(jq -r '.tool_input.task // ""' <<< "$input")
        if ! printf '%s\n' "$task" | grep -Eiq \
          'sbtn|sbt |scalafix|scalafmt|nix flake check|nix fmt|nix build|nix eval|cargo|pytest|ruff|black|mvn|mvnw|npm|pnpm|yarn|tsc|vue-tsc|eslint|vitest|diagnostic|no changes|nothing changed|no files changed'; then
          jq -n \
            '{approval: "deny",
              additionalContext: "Workflow gate: `verifier` task must name at least one concrete check command. Re-spawn `verifier` with the exact commands to run for the changed files (e.g. `sbtn test`, `pytest path/to/test.py`, `nix flake check`).",
              systemMessage: "Blocked spawn of `verifier`: task must name at least one concrete check command."}'
        fi
        ;;
    esac
  '';

  record = mkHook "eca-lead-workflow-record" ''
    input=$(cat)

    if [ "$(jq -r '.agent // ""' <<< "$input")" != "lead" ]; then
      exit 0
    fi

    target=$(jq -r '.tool_input.agent // ""' <<< "$input")
    target="''${target//[^a-zA-Z0-9_-]/_}"
    if [ -z "$target" ]; then
      exit 0
    fi

    dir=$(state_dir "$(jq -r '.session_id // ""' <<< "$input")" \
                    "$(jq -r '.chat_id // ""' <<< "$input")")
    mkdir -p "$dir"
    : > "$dir/$target"

    case "$target" in
      ${implementationAgents})
        : > "$dir/implementation"
        : > "$dir/needs-reviewer"
        rm -f "$dir/verifier" "$dir/reviewer"
        ;;
      verifier)
        ;;
      reviewer)
        rm -f "$dir/needs-reviewer"
        ;;
      *) ;;
    esac
  '';

  commitPolicy = protectedRoot: pkgs.writeShellApplication {
    name = "eca-git-preparer-commit-policy";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.git
      pkgs.jq
    ];
    text = ''
      input=$(cat)

      deny() {
        jq -n --arg context "$1" \
          '{approval: "deny", additionalContext: $context,
            systemMessage: "Commit avvist: norsk policy for git-preparer."}'
      }

      tool_name=$(jq -r '.tool_name // ""' <<< "$input")
      if [ "$tool_name" = "eca__git" ]; then
        operation=$(jq -r '.tool_input.operation // ""' <<< "$input")
        command=$(jq -r '.tool_input.command // ""' <<< "$input")
        commit_regex="(^|[[:space:];&|()])git([[:space:]]+[^;&|<>\`\$()]*)?[[:space:]]+commit([[:space:]]|\$)"
        if { [ "$operation" = "commit" ] || [[ "$command" =~ $commit_regex ]]; } &&
           [ "$(jq -r '.agent // ""' <<< "$input")" != "git-preparer" ]; then
          jq -n \
            '{approval: "deny",
              additionalContext: "Only `git-preparer` may commit through `eca__git`. Ask `git-preparer` to perform the verified commit.",
              systemMessage: "Blocked commit: only `git-preparer` may commit."}'
          exit 0
        fi
      else
        exit 0
      fi

      [ "$(jq -r '.agent // ""' <<< "$input")" = "git-preparer" ] || exit 0
      operation=$(jq -r '.tool_input.operation // ""' <<< "$input")
      cwd=$(jq -r '.cwd // ""' <<< "$input")
      command=$(jq -r '.tool_input.command // ""' <<< "$input")
      commit_regex="(^|[[:space:];&|()])git([[:space:]]+[^;&|<>\`\$()]*)?[[:space:]]+commit([[:space:]]|\$)"
      has_unsafe_literal() {
        case "$1" in
          *'$'*|*'`'*|*';'*|*'&'*|*'|'*|*'<'*|*'>'*|*$'\r'*|*$'\n'*)
            return 0 ;;
          *)
            return 1 ;;
        esac
      }
      directory=$cwd
      message=""
      accepted=false
      accepted_cd=false
      target_unverifiable=false
      if [ "$operation" != "commit" ]; then
        [[ "$command" =~ $commit_regex ]] || exit 0
        target_unverifiable=true
      fi
      unsafe_command=false
      if [[ "$command" =~ $commit_regex ]] &&
         [[ "$command" =~ git[[:space:]].*(-C|--git-dir|--work-tree)([[:space:]=]|$) ]]; then
        target_unverifiable=true
      fi
      direct_regex="^git[[:space:]]+commit[[:space:]]+-m[[:space:]]+'([^']*)'\$"
      cd_regex="^cd[[:space:]]+'([^']*)'[[:space:]]+&&[[:space:]]+git[[:space:]]+commit[[:space:]]+-m[[:space:]]+'([^']*)'\$"
      if [[ "$command" =~ $direct_regex ]]; then
        message="''${BASH_REMATCH[1]}"
        accepted=true
      elif [[ "$command" =~ $cd_regex ]]; then
        directory="''${BASH_REMATCH[1]}"
        message="''${BASH_REMATCH[2]}"
        case "$directory" in
          /*) ;;
          *) deny "Kunne ikke verifisere mål-repositoriet; cd må bruke en absolutt sti."; exit 0 ;;
        esac
        case "$directory" in
          *$'\n'*|*$'\r'*)
            deny "Kunne ikke verifisere mål-repositoriet; cd-stien inneholder kontrolltegn."; exit 0 ;;
        esac
        accepted=true
        accepted_cd=true
      elif [[ "$command" =~ ^git[[:space:]]+commit([[:space:]]|$) ]]; then
        :
      elif [ "$operation" = "commit" ]; then
        target_unverifiable=true
      elif [[ "$command" =~ $commit_regex ]]; then
        target_unverifiable=true
      else
        exit 0
      fi
      if [ "$accepted" = true ]; then
        fields="$message"
        [ "$accepted_cd" = true ] && fields="$directory$message"
        has_unsafe_literal "$fields" && unsafe_command=true
      elif [[ "$command" =~ $commit_regex ]] && has_unsafe_literal "$command"; then
        unsafe_command=true
      fi
      [ "$unsafe_command" = true ] && target_unverifiable=true

      case "$directory" in
        /*) ;;
        *) deny "Kunne ikke kontrollere canonical Git-root: top-level cwd mangler eller er ikke absolutt."; exit 0 ;;
      esac

      real_directory=$(realpath -e -- "$directory" 2>/dev/null || true)
      if [ -z "$real_directory" ]; then
        deny "Kunne ikke verifisere katalogen eller canonical Git-root; vis root med read-only kommandoer og prøv igjen."; exit 0
      fi
      root=$(git -C "$real_directory" rev-parse --path-format=absolute --show-toplevel 2>/dev/null || true)
      root=$(realpath -e -- "$root" 2>/dev/null || true)
      if [ -z "$root" ]; then
        deny "Kunne ikke fastslå canonical Git-root; commit er avvist inntil repository-roten kan verifiseres."; exit 0
      fi

      protected=false
      case "$root" in
        ${protectedRoot}|${protectedRoot}/*) protected=true ;;
      esac
      if [ "$target_unverifiable" = true ]; then
        if [ "$protected" = true ]; then
          deny "Canonical Git-root er $root. Kunne ikke verifisere mål-repositoriet; bruk hookens eksakte form git commit -m '…' (eventuelt cd '/absolutt/sti' && git commit -m '…').";
        else
          deny "Kunne ikke verifisere mål-repositoriet; commit er avvist når kommandoen kan endre mål-repositoriet. Canonical Git-root er $root.";
        fi
        exit 0
      fi
      [ "$protected" = true ] || exit 0

      if [ "$accepted" != true ] || [[ "$message" == *$'\n'* || "$message" == *$'\r'* ]]; then
        deny "Canonical Git-root er $root. Beskyttede repositorier krever nøyaktig git commit -m '…' med én linje; -F/--file, editor-meldinger, flere -m og shell-sammensetning er ikke tillatt."; exit 0
      fi
      subject="''${message#*: }"
      if [[ ! "$message" =~ ^[a-z][a-z0-9-]*(\([a-z0-9][a-z0-9._/-]*\))?!?:[[:space:]][a-z].*$ ]] ||
         [[ "$subject" =~ [[:upper:]] ]] ||
         [[ "$message" == *. ]] ||
         [[ ! "$subject" =~ ^(legg\ til|fjern|oppdater|rett|tillat|gjør|korriger|refaktorer|forbedre|bruk|støtt|flytt|endre|sikre|håndter|forenkle|dokumenter|test|bygg)[[:space:]]+.+$ ]]; then
        deny "Canonical Git-root er $root. Commit-meldingen må ha Conventional Commit-form og et norsk imperativ i allowlisten (legg til, fjern, oppdater, rett, tillat, gjør, korriger, refaktorer, forbedre, bruk, støtt, flytt, endre, sikre, håndter, forenkle, dokumenter, test eller bygg), uten punktum."; exit 0
      fi
    '';
  };

  verify = mkHook "eca-lead-workflow-verify" ''
    input=$(cat)

    if [ "$(jq -r '.agent // ""' <<< "$input")" != "lead" ] ||
       [ "$(jq -r '.follow_up_active // false' <<< "$input")" = "true" ]; then
      exit 0
    fi

    dir=$(state_dir "$(jq -r '.session_id // ""' <<< "$input")" \
                    "$(jq -r '.chat_id // ""' <<< "$input")")

    if [ -e "$dir/implementation" ] && [ ! -e "$dir/verifier" ]; then
      if [ ! -e "$dir/nagged-verifier" ]; then
        : > "$dir/nagged-verifier"
        jq -n \
          '{followUp: "Implementation subagents changed code but `verifier` has not run. Spawn `verifier` now with the exact checks for what changed (e.g. `sbtn test`, `pytest path/to/test.py`, `nix flake check`). If nothing was changed, state that instead.",
            systemMessage: "Workflow: forcing a verification turn."}'
      fi
    elif [ -e "$dir/implementation" ] && [ -e "$dir/needs-reviewer" ]; then
      if [ ! -e "$dir/nagged-reviewer" ]; then
        : > "$dir/nagged-reviewer"
        jq -n \
          '{followUp: "Verification passed. Spawn `reviewer` on the final diff before reporting completion. Also spawn `security` if the change touches auth, secrets, shell execution, permissions, networking, persistence, or user data.",
            systemMessage: "Workflow: forcing a review turn."}'
      fi
    elif [ -e "$dir/implementation" ] && [ -e "$dir/verifier" ] && [ -e "$dir/reviewer" ]; then
      rm -f "$dir/implementation" "$dir/needs-reviewer" "$dir/verifier" "$dir/reviewer" \
            "$dir/architect" "$dir/nagged-verifier" "$dir/nagged-reviewer"
    fi
  '';
}
