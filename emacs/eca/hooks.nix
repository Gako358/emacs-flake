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
