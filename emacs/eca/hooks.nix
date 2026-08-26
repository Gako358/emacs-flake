{ pkgs }:
let
  # Agents that may only run once `architect` has returned a plan for the chat.
  implementationAgents = "backend|frontend|scala|java|refactorer|docs";

  stateSnippet = ''
    state_dir() {
      local root="''${XDG_RUNTIME_DIR:-/tmp}/eca-lead-workflow"
      printf '%s/%s/%s' "$root" "''${1//[^a-zA-Z0-9_.-]/_}" "''${2//[^a-zA-Z0-9_.-]/_}"
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
      *) exit 0 ;;
    esac

    dir=$(state_dir "$(jq -r '.session_id // ""' <<< "$input")" \
                    "$(jq -r '.chat_id // ""' <<< "$input")")

    if [ ! -e "$dir/architect" ]; then
      jq -n --arg agent "$target" \
        '{approval: "deny",
          additionalContext: ("Workflow gate: no architect plan exists for this chat yet. Spawn `architect` with the full task first, then delegate to `" + $agent + "` with the resulting plan."),
          systemMessage: ("Blocked spawn of `" + $agent + "`: architect plan required first.")}'
    fi
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
        rm -f "$dir/verifier"
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
      rm -f "$dir/implementation"
      jq -n \
        '{followUp: "Implementation subagents changed code but `verifier` has not run. Spawn `verifier` now with the exact checks for what changed, and `reviewer` if the diff is non-trivial. If nothing was changed, state that instead.",
          systemMessage: "Workflow: forcing a verification turn."}'
    fi
  '';
}
