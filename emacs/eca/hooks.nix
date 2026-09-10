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
    classification_lines=$(printf '%s\n' "$task" | sed -n '/^[[:space:]]*Security review:/p')
    classification_count=$(printf '%s\n' "$classification_lines" | sed '/^$/d' | wc -l)
    valid_classification_lines=$(printf '%s\n' "$classification_lines" | grep -E '^[[:space:]]*Security review:[[:space:]]*(required|not-required)[[:space:]]*$' || true)
    valid_classification_count=$(printf '%s\n' "$valid_classification_lines" | sed '/^$/d' | wc -l)
    classification=""
    if [ "$classification_count" -eq 1 ] && [ "$valid_classification_count" -eq 1 ]; then
      classification=$(printf '%s\n' "$valid_classification_lines" | sed -E 's/^[[:space:]]*Security review:[[:space:]]*//; s/[[:space:]]*$//')
    fi
  '';
  metadataCheck = ''
    task=$(jq -r '.tool_input.task // ""' <<< "$input")
    ac_count=$(printf '%s\n' "$task" | grep -Eo '(^|[^[:alnum:]_-])AC-[0-9]{2,}([^[:alnum:]_-]|$)' | wc -l || true)
    workstream_count=$(printf '%s\n' "$task" | grep -Eo '(^|[^[:alnum:]_-])Workstream ID: WF-[A-Z0-9_-]+([^[:alnum:]_-]|$)' | wc -l || true)
    task_id_count=$(printf '%s\n' "$task" | grep -Eo '(^|[^[:alnum:]_-])Task ID: WF-[A-Z0-9_-]+([^[:alnum:]_-]|$)' | wc -l || true)
    if [ "$ac_count" -ne 1 ] || [ "$workstream_count" -ne 1 ] || [ "$task_id_count" -ne 1 ]; then
      validation_fail "Workflow gate: include exactly one stable AC-##, Workstream ID: WF-..., and Task ID: WF-...." "Blocked: incomplete or ambiguous workflow metadata."
    fi
    intent_matches=$(printf '%s\n' "$task" | grep -Eo 'Workflow intent:[[:space:]]*[a-z-]+' || true)
    intent_count=$(printf '%s\n' "$intent_matches" | sed '/^$/d' | wc -l)
    if [ "$intent_count" -ne 1 ]; then
      validation_fail "Workflow gate: provide exactly one clear Workflow intent value; do not repeat or bury it in prose." "Blocked: workflow intent is missing or ambiguous."
    fi
    intent=$(printf '%s\n' "$intent_matches" | sed -E 's/^Workflow intent:[[:space:]]*//')
    case "$target:$intent" in
      architect:plan|architect:risk|verifier:verification|reviewer:review|security:security|summary:summary) ;;
      backend:implementation|backend:integration|backend:remediation|frontend:implementation|frontend:integration|frontend:remediation|scala:implementation|scala:integration|scala:remediation|java:implementation|java:integration|java:remediation|refactorer:implementation|refactorer:integration|refactorer:remediation|docs:implementation|docs:integration|docs:remediation) ;;
      *) validation_fail "Target $target does not accept Workflow intent: $intent." "Blocked: target and workflow intent do not match." ;;
    esac
    ${classificationParse}
    if [ "$target" = verifier ] && [ -z "$classification" ]; then
      validation_fail "Verifier assignment must contain exactly one line consisting of Security review: required or Security review: not-required." "Blocked: security review classification is missing, duplicated, or malformed."
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
    validation_fail() {
      jq -n --arg context "$1" --arg message "$2" '{approval:"deny",additionalContext:$context,systemMessage:$message}'
      exit 0
    }
    follow_up_active=$(jq -r '.follow_up_active // false' <<< "$input")
    dir=$(state_dir "$session" "$chat")
    ${metadataCheck}
    case "$target" in
      architect)
        if [ "$intent" = risk ] && [ -e "$dir/remediation-used" ]; then
          jq -n '{approval:"deny",additionalContext:"Architect risk is unavailable after the consolidated remediation pass has been used.",systemMessage:"Blocked architect risk: remediation already used."}'; exit 0
        elif [ "$intent" = plan ] && [ -e "$dir/implementation-invoked" ] && [ ! -e "$dir/summary-invoked" ]; then
          jq -n '{approval:"deny",additionalContext:"A plan invocation is valid before implementation starts or after summary starts a fresh workflow; use risk for later assessment.",systemMessage:"Blocked architect plan: implementation already invoked."}'; exit 0
        elif [ "$intent" = risk ] && { [ ! -e "$dir/verifier-invoked" ] || [ -e "$dir/reviewer-invoked" ] || [ -e "$dir/security-invoked" ]; }; then
          jq -n '{approval:"deny",additionalContext:"Risk requires verifier invocation and must occur before reviewer or security invocation.",systemMessage:"Blocked architect risk: gate ordering is not satisfied."}'; exit 0
        fi ;;
      ${implementationAgents})
        if [ ! -e "$dir/architect-invoked" ]; then
          jq -n '{approval:"deny",additionalContext:"Architect invocation is required. This hook proves invocation only; lead must separately await and validate the populated register and tracker readback.",systemMessage:"Blocked: architect invocation required."}'
          exit 0
        fi
        if [ "$follow_up_active" = true ]; then
          case "$intent" in implementation|remediation) ;;
            *) jq -n '{approval:"deny",additionalContext:"Active follow-up spawns must be implementation or eligible remediation work; out-of-order follow-up work is denied.",systemMessage:"Blocked follow-up: implementation or remediation intent required."}'; exit 0 ;;
          esac
        fi
        if [ -e "$dir/remediation-used" ]; then
          jq -n '{approval:"deny",additionalContext:"No implementation-agent intent is allowed after the consolidated remediation pass has been used.",systemMessage:"Blocked implementation agent: remediation already used."}'; exit 0
        elif [ "$intent" = remediation ]; then
          if [ ! -e "$dir/verifier-invoked" ] || [ ! -e "$dir/reviewer-invoked" ] || { [ -e "$dir/security-required" ] && [ ! -e "$dir/security-invoked" ]; }; then
            jq -n '{approval:"deny",additionalContext:"Remediation requires verifier and reviewer invocation, plus security invocation when security review is required. Hooks prove invocation only; lead must reconcile actual reports.",systemMessage:"Blocked remediation: required gate invocations are missing."}'
            exit 0
          fi
          mkdir -p "$dir"
          chmod 700 "''${dir%/*}" "$dir"
          if mkdir "$dir/remediation-dispatch" 2>/dev/null; then
            chmod 700 "$dir/remediation-dispatch"
          fi
          if ! mkdir "$dir/remediation-dispatch/$target" 2>/dev/null; then
            jq -n '{approval:"deny",additionalContext:"This implementation domain is already reserved in the single parallel remediation batch.",systemMessage:"Blocked remediation: duplicate or later dispatch."}'
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
    target=$(jq -r '.tool_input.agent // ""' <<< "$input")
    case "$target" in ${implementationAgents}|verifier|reviewer|security|summary|architect) ;; *) exit 0 ;; esac
    validation_fail() { exit 0; }
    ${metadataCheck}
    dir=$(state_dir "$session" "$chat")
    mkdir -p "$dir"
    chmod 700 "''${dir%/*}" "$dir"
    if [ "$target" = architect ] && [ "$intent" = plan ] && [ -e "$dir/summary-invoked" ]; then
      rm -f "$dir"/*-invoked "$dir"/security-required "$dir"/remediation-used "$dir"/nagged-*
      for domain in backend frontend scala java refactorer docs; do rmdir "$dir/remediation-dispatch/$domain" 2>/dev/null || true; done
      rmdir "$dir/remediation-dispatch" 2>/dev/null || true
    fi
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
        if [ "$classification" = required ]; then : > "$dir/security-required"; fi ;;
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
