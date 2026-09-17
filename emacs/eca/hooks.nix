{ pkgs }:
let
  implementationAgents = "backend|frontend|scala|java|refactorer|docs";
  stateSnippet = ''
    umask 077
    state_dir() {
      local root="''${XDG_RUNTIME_DIR:-/tmp}/eca-lead-workflow-$UID"
      printf '%s/%s/%s' "$root" "''${1//[^a-zA-Z0-9_-]/_}" "''${2//[^a-zA-Z0-9_-]/_}"
    }
  '';
  mkHook = name: text: pkgs.writeShellApplication {
    inherit name;
    runtimeInputs = [ pkgs.jq pkgs.coreutils pkgs.gnugrep pkgs.gnused ];
    text = stateSnippet + text;
  };
  gitApproval = mkHook "eca-version-git-approval" ''
    input=$(cat)
    actor=$(jq -r '.agent // ""' <<< "$input")
    [ "$actor" = version ] || exit 0
    command=$(jq -r '.tool_input.command // ""' <<< "$input")
    # shellcheck disable=SC2016
    if printf '%s\n' "$command" | grep -Eq '[;&|<>`$()]'; then
      exit 0
    fi
    if printf '%s\n' "$command" | grep -Eq '^git[[:space:]]+(fetch|pull|branch|switch|checkout|merge|rebase|cherry-pick|bisect|add|restore|commit|push|reset|clean|reflog|status|diff|log|show|rev-parse)([[:space:]]|$)'; then
      jq -n '{approval:"allow"}'
    fi
  '';
  gate = mkHook "eca-lead-workflow-gate" ''
    cat >/dev/null
  '';
in
{
  inherit gitApproval gate;

  record = mkHook "eca-lead-workflow-record" ''
    input=$(cat)
    actor=$(jq -r '.agent // ""' <<< "$input")
    [ "$actor" = lead ] || exit 0
    session=$(jq -r '.session_id // ""' <<< "$input")
    chat=$(jq -r '.chat_id // ""' <<< "$input")
    [ -n "$session" ] && [ -n "$chat" ] || exit 0
    target=$(jq -r '.tool_input.agent // ""' <<< "$input")
    case "$target" in ${implementationAgents}|verifier|reviewer|security|summary|architect) ;; *) exit 0 ;; esac
    task=$(jq -r '.tool_input.task // ""' <<< "$input")
    dir=$(state_dir "$session" "$chat")
    mkdir -p "$dir"
    chmod 700 "''${dir%/*}" "$dir"
    if [ "$target" = architect ] && [ -e "$dir/summary-invoked" ]; then
      rm -f "$dir"/*-invoked "$dir"/security-required
    fi
    : > "$dir/$target-invoked"
    case "$target" in
      architect) : > "$dir/architect-invoked" ;;
      ${implementationAgents})
        : > "$dir/implementation-invoked"
        rm -f "$dir/verifier-invoked" "$dir/reviewer-invoked" "$dir/security-invoked" "$dir/summary-invoked"
        ;;
      verifier)
        if printf '%s\n' "$task" | grep -Eq '^[[:space:]]*Security review:[[:space:]]*required[[:space:]]*$'; then
          : > "$dir/security-required"
        fi
        ;;
    esac
  '';

  verify = mkHook "eca-lead-workflow-verify" ''
    input=$(cat)
    actor=$(jq -r '.agent // ""' <<< "$input")
    [ "$actor" = lead ] || exit 0
    [ "$(jq -r '.follow_up_active // false' <<< "$input")" = true ] && exit 0
    session=$(jq -r '.session_id // ""' <<< "$input")
    chat=$(jq -r '.chat_id // ""' <<< "$input")
    [ -n "$session" ] && [ -n "$chat" ] || exit 0
    dir=$(state_dir "$session" "$chat")
    if [ -e "$dir/implementation-invoked" ] && [ ! -e "$dir/verifier-invoked" ]; then
      jq -n '{followUp:"Implementation/integration was invoked but verifier evidence is missing. Spawn verifier with per-AC/task PASSED, FAILED, or UNVERIFIED evidence and literal commands.",systemMessage:"Workflow: continue with verification."}'
    elif [ -e "$dir/verifier-invoked" ] && [ ! -e "$dir/reviewer-invoked" ]; then
      jq -n '{followUp:"Verifier was invoked but reviewer is missing. Spawn reviewer; invoke required security review too. Inspect actual PASSED/CLEAR/FINDINGS reports.",systemMessage:"Workflow: continue with review."}'
    elif [ -e "$dir/reviewer-invoked" ] && [ -e "$dir/security-required" ] && [ ! -e "$dir/security-invoked" ]; then
      jq -n '{followUp:"Reviewer was invoked and security review is required. Spawn security and inspect its actual CLEAR/FINDINGS report.",systemMessage:"Workflow: continue with security review."}'
    elif [ -e "$dir/verifier-invoked" ] && [ -e "$dir/reviewer-invoked" ] && [ ! -e "$dir/summary-invoked" ] && { [ ! -e "$dir/security-required" ] || [ -e "$dir/security-invoked" ]; }; then
      jq -n '{followUp:"All required gate invocations are present. Inspect the latest reports, continue with a consolidated remediation batch while findings remain, or spawn summary after PASSED and CLEAR outcomes.",systemMessage:"Workflow: continue until the plan is complete."}'
    fi
  '';
}
