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
  classificationParse = ''
    classification_tokens=$(printf '%s\n' "$task" | grep -Eo 'Security review:[^;]*' || true)
    classification_count=$(printf '%s\n' "$classification_tokens" | sed '/^$/d' | wc -l)
    classification=""
    if [ "$classification_count" -eq 1 ]; then
      classification=$(printf '%s\n' "$classification_tokens" | sed -E 's/^Security review:[[:space:]]*//; s/[[:space:]]*$//')
      case "$classification" in required|not-required) ;; *) classification="" ;; esac
    fi
  '';
  metadataCheck = ''
    task=$(jq -r '.tool_input.task // ""' <<< "$input")
    if ! printf '%s\n' "$task" | grep -Eq '(^|[^[:alnum:]_-])AC-[0-9]{2,}([^[:alnum:]_-]|$)' || ! printf '%s\n' "$task" | grep -Eq '(^|[^[:alnum:]_-])Workstream ID: WF-[A-Z0-9_-]+([^[:alnum:]_-]|$)' || ! printf '%s\n' "$task" | grep -Eq '(^|[^[:alnum:]_-])Task ID: WF-[A-Z0-9_-]+([^[:alnum:]_-]|$)'; then
      jq -n '{approval:"deny",additionalContext:"Workflow gate: include a stable AC-##, `Workstream ID: WF-...`, and `Task ID: WF-...`.",systemMessage:"Blocked: incomplete workflow metadata."}'
      exit 0
    fi
    intent_matches=$(printf '%s\n' "$task" | grep -Eo 'Workflow intent:[[:space:]]*[a-z-]+' || true)
    intent_count=$(printf '%s\n' "$intent_matches" | sed '/^$/d' | wc -l)
    if [ "$intent_count" -ne 1 ]; then
      jq -n '{approval:"deny",additionalContext:"Workflow gate: provide exactly one clear `Workflow intent: ...` value; do not repeat or bury it in prose.",systemMessage:"Blocked: workflow intent is missing or ambiguous."}'
      exit 0
    fi
    intent=$(printf '%s\n' "$intent_matches" | sed -E 's/^Workflow intent:[[:space:]]*//')
    case "$intent" in
      plan|risk|implementation|integration|remediation|verification|review|security|summary) ;;
      *) jq -n --arg intent "$intent" '{approval:"deny",additionalContext:("Workflow intent `"+$intent+"` is invalid. Use a target-compatible plan, risk, implementation, integration, remediation, verification, review, security, or summary intent."),systemMessage:"Blocked: invalid workflow intent."}'; exit 0 ;;
    esac
    case "$target" in
      architect) case "$intent" in plan|risk) ;; *) jq -n --arg target "$target" --arg intent "$intent" '{approval:"deny",additionalContext:("Target `"+$target+"` accepts only `Workflow intent: plan` or `Workflow intent: risk`, not `"+$intent+"`."),systemMessage:"Blocked: target and workflow intent do not match."}'; exit 0 ;; esac ;;
      ${implementationAgents}) case "$intent" in implementation|integration|remediation) ;; *) jq -n --arg target "$target" --arg intent "$intent" '{approval:"deny",additionalContext:("Implementation agent `"+$target+"` accepts implementation, integration, or remediation intent; received `"+$intent+"`."),systemMessage:"Blocked: target and workflow intent do not match."}'; exit 0 ;; esac ;;
      verifier) [ "$intent" = verification ] || { jq -n '{approval:"deny",additionalContext:"Verifier spawns require `Workflow intent: verification`.",systemMessage:"Blocked: target and workflow intent do not match."}'; exit 0; } ;;
      reviewer) [ "$intent" = review ] || { jq -n '{approval:"deny",additionalContext:"Reviewer spawns require `Workflow intent: review`.",systemMessage:"Blocked: target and workflow intent do not match."}'; exit 0; } ;;
      security) [ "$intent" = security ] || { jq -n '{approval:"deny",additionalContext:"Security spawns require `Workflow intent: security`.",systemMessage:"Blocked: target and workflow intent do not match."}'; exit 0; } ;;
      summary) [ "$intent" = summary ] || { jq -n '{approval:"deny",additionalContext:"Summary spawns require `Workflow intent: summary`.",systemMessage:"Blocked: target and workflow intent do not match."}'; exit 0; } ;;
    esac
    if [ "$target" = verifier ]; then
      classification_tokens=$(printf '%s\n' "$task" | grep -Eo 'Security review:[^;]*' || true)
      classification_count=$(printf '%s\n' "$classification_tokens" | sed '/^$/d' | wc -l)
      classification=""
      if [ "$classification_count" -eq 1 ]; then
        classification=$(printf '%s\n' "$classification_tokens" | sed -E 's/^Security review:[[:space:]]*//; s/[[:space:]]*$//')
        case "$classification" in required|not-required) ;; *) classification="" ;; esac
      fi
      if [ -z "$classification" ]; then
        jq -n '{approval:"deny",additionalContext:"Verifier assignment must contain exactly one `Security review: required` or `Security review: not-required` token with no trailing extension.",systemMessage:"Blocked: security review classification is missing, duplicated, or malformed."}'
        exit 0
      fi
    fi
  '';
in
{
  gate = mkHook "eca-lead-workflow-gate" ''
    input=$(cat)
    [ "$(jq -r '.agent // ""' <<< "$input")" = lead ] || exit 0
    session=$(jq -r '.session_id // ""' <<< "$input")
    chat=$(jq -r '.chat_id // ""' <<< "$input")
    if [ -z "$session" ] || [ -z "$chat" ]; then
      jq -n '{approval:"deny",additionalContext:"Workflow gate requires non-empty session_id and chat_id; refusing to share an unscoped state directory.",systemMessage:"Blocked: workflow state cannot be scoped."}'
      exit 0
    fi
    target=$(jq -r '.tool_input.agent // ""' <<< "$input")
    case "$target" in ${implementationAgents}|verifier|reviewer|security|summary|architect) ;; *) exit 0 ;; esac
    follow_up_active=$(jq -r '.follow_up_active // false' <<< "$input")
    dir=$(state_dir "$session" "$chat")
    ${metadataCheck}
    case "$target" in
      architect)
        if [ "$intent" = risk ] && [ -e "$dir/remediation-used" ]; then
          jq -n '{approval:"deny",additionalContext:"Architect risk is unavailable after the consolidated remediation pass has been used.",systemMessage:"Blocked architect risk: remediation already used."}'; exit 0
        elif [ "$intent" = plan ] && [ -e "$dir/implementation-invoked" ]; then
          jq -n '{approval:"deny",additionalContext:"A plan invocation is only valid before implementation has started; use a risk intent for later assessment.",systemMessage:"Blocked architect plan: implementation already invoked."}'; exit 0
        elif [ "$intent" = risk ] && { [ ! -e "$dir/verifier-invoked" ] || [ -e "$dir/reviewer-invoked" ] || [ -e "$dir/security-invoked" ]; }; then
          jq -n '{approval:"deny",additionalContext:"Risk requires verifier invocation and must occur before reviewer or security invocation.",systemMessage:"Blocked architect risk: gate ordering is not satisfied."}'; exit 0
        fi ;;
      ${implementationAgents})
        if [ ! -e "$dir/architect-invoked" ]; then
          jq -n '{approval:"deny",additionalContext:"Architect invocation is required. This hook proves invocation only; lead must separately await and validate the populated register and tracker readback.",systemMessage:"Blocked: architect invocation required."}'
          exit 0
        fi
        if [ "$follow_up_active" = true ] && [ "$intent" != implementation ]; then
          jq -n '{approval:"deny",additionalContext:"Active follow-up spawns must be implementation work; out-of-order follow-up work is denied.",systemMessage:"Blocked follow-up: implementation intent required."}'
          exit 0
        fi
        if [ -e "$dir/remediation-used" ]; then
          jq -n '{approval:"deny",additionalContext:"No implementation-agent intent is allowed after the consolidated remediation pass has been used.",systemMessage:"Blocked implementation agent: remediation already used."}'; exit 0
        elif [ "$intent" = remediation ]; then
          if [ ! -e "$dir/verifier-invoked" ] || [ ! -e "$dir/reviewer-invoked" ] || { [ -e "$dir/security-required" ] && [ ! -e "$dir/security-invoked" ]; }; then
            jq -n '{approval:"deny",additionalContext:"Remediation requires verifier and reviewer invocation, plus security invocation when security review is required. Hooks prove invocation only; lead must reconcile actual reports.",systemMessage:"Blocked remediation: required gate invocations are missing."}'
            exit 0
          fi
          if [ -e "$dir/remediation-used" ]; then
            jq -n '{approval:"deny",additionalContext:"The single consolidated remediation pass has already been used.",systemMessage:"Blocked remediation: no remediation pass remains."}'
            exit 0
          fi
        elif [ -e "$dir/reviewer-invoked" ] || [ -e "$dir/security-invoked" ]; then
          jq -n '{approval:"deny",additionalContext:"Reviewer or security has begun. Use `Workflow intent: remediation` after reconciling findings for one consolidated pass.",systemMessage:"Blocked implementation: downstream review has begun."}'; exit 0
        fi ;;
      verifier)
        [ -e "$dir/implementation-invoked" ] || { jq -n '{approval:"deny",additionalContext:"Implementation/integration must be invoked before verification.",systemMessage:"Blocked verifier: implementation required."}'; exit 0; }
        printf '%s\n' "$task" | grep -Eiq 'nix build|nix flake check|test|compile|diagnostic|lint|format|check' || { jq -n '{approval:"deny",additionalContext:"Verifier assignment must name concrete checks and evidence requirements.",systemMessage:"Blocked verifier: concrete checks required."}'; exit 0; } ;;
      reviewer|security)
        [ -e "$dir/verifier-invoked" ] || { jq -n '{approval:"deny",additionalContext:"Review/security invocation requires verifier invocation first; hooks do not observe returned outcomes.",systemMessage:"Blocked review: verifier invocation required."}'; exit 0; } ;;
      summary)
        [ -e "$dir/verifier-invoked" ] && [ -e "$dir/reviewer-invoked" ] || { jq -n '{approval:"deny",additionalContext:"Summary requires verifier and reviewer invocation. Lead/summary must additionally prove actual latest PASSED/CLEAR reports.",systemMessage:"Blocked summary: required gate invocations missing."}'; exit 0; }
        [ ! -e "$dir/security-required" ] || [ -e "$dir/security-invoked" ] || { jq -n '{approval:"deny",additionalContext:"Security review is required and has not been invoked. Hooks prove invocation only; summary must require an actual latest CLEAR report.",systemMessage:"Blocked summary: security invocation required."}'; exit 0; } ;;
    esac
  '';

  record = mkHook "eca-lead-workflow-record" ''
    input=$(cat)
    [ "$(jq -r '.agent // ""' <<< "$input")" = lead ] || exit 0
    session=$(jq -r '.session_id // ""' <<< "$input")
    chat=$(jq -r '.chat_id // ""' <<< "$input")
    [ -n "$session" ] && [ -n "$chat" ] || exit 0
    target="$(jq -r '.tool_input.agent // ""' <<< "$input")"; target="''${target//[^a-zA-Z0-9_-]/_}"
    [ -n "$target" ] || exit 0
    task=$(jq -r '.tool_input.task // ""' <<< "$input")
    intent=$(printf '%s\n' "$task" | grep -Eo 'Workflow intent:[[:space:]]*[a-z-]+' | sed -E 's/^Workflow intent:[[:space:]]*//' | head -n1)
    classification_tokens=$(printf '%s\n' "$task" | grep -Eo 'Security review:[^;]*' || true)
    classification_count=$(printf '%s\n' "$classification_tokens" | sed '/^$/d' | wc -l)
    classification=""
    if [ "$classification_count" -eq 1 ]; then
      classification=$(printf '%s\n' "$classification_tokens" | sed -E 's/^Security review:[[:space:]]*//; s/[[:space:]]*$//')
      case "$classification" in required|not-required) ;; *) classification="" ;; esac
    fi
    dir=$(state_dir "$session" "$chat"); mkdir -p "$dir"; chmod 700 "''${dir%/*}" "$dir"
    : > "$dir/$target-invoked"
    case "$target" in
      architect) : > "$dir/architect-invoked" ;;
      ${implementationAgents})
        : > "$dir/implementation-invoked"
        rm -f "$dir/verifier-invoked" "$dir/reviewer-invoked" "$dir/security-invoked" "$dir/summary-invoked" "$dir/nagged-verifier" "$dir/nagged-reviewer" "$dir/nagged-security" "$dir/nagged-reconcile"
        if [ "$intent" = remediation ]; then
          : > "$dir/remediation-used"
        fi ;;
      verifier)
        [ -e "$dir/implementation-invoked" ] && : > "$dir/verifier-invoked"
        if [ "$classification" = required ]; then : > "$dir/security-required"; else rm -f "$dir/security-required"; fi ;;
      reviewer|security) [ -e "$dir/verifier-invoked" ] && : > "$dir/$target-invoked" ;;
      summary) : > "$dir/summary-invoked" ;;
    esac
  '';

  verify = mkHook "eca-lead-workflow-verify" ''
    input=$(cat)
    [ "$(jq -r '.agent // ""' <<< "$input")" = lead ] || exit 0
    [ "$(jq -r '.follow_up_active // false' <<< "$input")" = true ] && exit 0
    session=$(jq -r '.session_id // ""' <<< "$input")
    chat=$(jq -r '.chat_id // ""' <<< "$input")
    [ -n "$session" ] && [ -n "$chat" ] || exit 0
    dir=$(state_dir "$session" "$chat")
    if [ -e "$dir/implementation-invoked" ] && [ ! -e "$dir/verifier-invoked" ]; then
      if [ ! -e "$dir/nagged-verifier" ]; then
        : > "$dir/nagged-verifier"
        jq -n '{followUp:"Implementation/integration was invoked but verifier evidence is missing. Spawn verifier with per-AC/task PASSED, FAILED, or UNVERIFIED evidence and literal commands.",systemMessage:"Workflow: forcing verification invocation."}'
      fi
    elif [ -e "$dir/verifier-invoked" ] && [ ! -e "$dir/reviewer-invoked" ]; then
      if [ ! -e "$dir/nagged-reviewer" ]; then
        : > "$dir/nagged-reviewer"
        jq -n '{followUp:"Verifier was invoked but reviewer is missing. Spawn reviewer; invoke required security review too. Hooks prove invocation only: inspect actual PASSED/CLEAR/FINDINGS reports.",systemMessage:"Workflow: forcing reviewer invocation."}'
      fi
    elif [ -e "$dir/reviewer-invoked" ] && [ -e "$dir/security-required" ] && [ ! -e "$dir/security-invoked" ]; then
      if [ ! -e "$dir/nagged-security" ]; then
        : > "$dir/nagged-security"
        jq -n '{followUp:"Reviewer was invoked and security review is required. Spawn security and inspect its actual CLEAR/FINDINGS report.",systemMessage:"Workflow: forcing security invocation."}'
      fi
    elif [ -e "$dir/verifier-invoked" ] && [ -e "$dir/reviewer-invoked" ] && { [ ! -e "$dir/security-required" ] || [ -e "$dir/security-invoked" ]; }; then
      if [ ! -e "$dir/nagged-reconcile" ]; then
        : > "$dir/nagged-reconcile"
        jq -n '{followUp:"All required gate invocations are present. Inspect the actual latest PASSED/CLEAR/FINDINGS reports and choose exactly one consolidated remediation with eligible intent or an eligible summary; do not infer outcomes from hooks.",systemMessage:"Workflow: reconcile evidence before remediation or summary."}'
      fi
    fi
  '';
}
