{ pkgs }:
let
  implementationAgents = "backend|frontend|scala|java|refactorer|docs";
  stateSnippet = ''
    state_dir() {
      local root="''${XDG_RUNTIME_DIR:-/tmp}/eca-lead-workflow"
      printf '%s/%s/%s' "$root" "''${1//[^a-zA-Z0-9_-]/_}" "''${2//[^a-zA-Z0-9_-]/_}"
    }
  '';
  mkHook = name: text: pkgs.writeShellApplication {
    inherit name;
    runtimeInputs = [ pkgs.jq pkgs.coreutils ];
    text = stateSnippet + text;
  };
in
{
  gate = mkHook "eca-lead-workflow-gate" ''
    input=$(cat)
    [ "$(jq -r '.agent // ""' <<< "$input")" = lead ] || exit 0
    [ "$(jq -r '.follow_up_active // false' <<< "$input")" = true ] && exit 0
    target=$(jq -r '.tool_input.agent // ""' <<< "$input")
    case "$target" in ${implementationAgents}|verifier|reviewer) ;; *) exit 0 ;; esac
    dir=$(state_dir "$(jq -r '.session_id // ""' <<< "$input")" "$(jq -r '.chat_id // ""' <<< "$input")")
    case "$target" in
      ${implementationAgents})
        if [ ! -e "$dir/architect" ]; then
          if [ -e "$dir/remediation-ready" ] && printf '%s' "$(jq -r '.tool_input.task // ""' <<< "$input")" | grep -Eiq 'consolidated remediation|remediation.*(fix|finding)|fix.*finding'; then
            : > "$dir/remediation-used"; rm -f "$dir/remediation-ready"
          else
            jq -n --arg agent "$target" '{approval:"deny",additionalContext:("Workflow gate: no architect plan exists for this chat yet. Spawn `architect` first, or identify this as the consolidated remediation/fix-findings pass.") ,systemMessage:("Blocked spawn of `"+$agent+"`: architect plan required first.")}'
          fi
        fi ;;
      verifier)
        task=$(jq -r '.tool_input.task // ""' <<< "$input")
        if ! printf '%s\n' "$task" | grep -Eiq 'sbtn|sbt |scalafix|scalafmt|nix flake check|nix fmt|nix build|nix eval|cargo|pytest|ruff|black|mvn|mvnw|npm|pnpm|yarn|tsc|vue-tsc|eslint|vitest'; then
          jq -n '{approval:"deny",additionalContext:"Workflow gate: verifier task must name a concrete check command.",systemMessage:"Blocked verifier: concrete check required."}'
        fi ;;
      reviewer)
        [ -e "$dir/verifier" ] || jq -n '{approval:"deny",additionalContext:"Workflow gate: verification must complete before review.",systemMessage:"Blocked reviewer: verification required."}' ;;
    esac
  '';

  record = mkHook "eca-lead-workflow-record" ''
    input=$(cat)
    [ "$(jq -r '.agent // ""' <<< "$input")" = lead ] || exit 0
    [ "$(jq -r '.follow_up_active // false' <<< "$input")" = true ] && exit 0
    target="$(jq -r '.tool_input.agent // ""' <<< "$input")"; target="''${target//[^a-zA-Z0-9_-]/_}"
    [ -n "$target" ] || exit 0
    dir=$(state_dir "$(jq -r '.session_id // ""' <<< "$input")" "$(jq -r '.chat_id // ""' <<< "$input")"); mkdir -p "$dir"; : > "$dir/$target"
    case "$target" in
      ${implementationAgents})
        : > "$dir/implementation"; : > "$dir/needs-reviewer"
        rm -f "$dir/verifier" "$dir/reviewer" "$dir/nagged-verifier" "$dir/nagged-reviewer" ;;
      verifier) [ -e "$dir/implementation" ] && : > "$dir/verifier" ;;
      reviewer) [ -e "$dir/verifier" ] && rm -f "$dir/needs-reviewer" ;;
    esac
  '';

  commitPolicy = protectedRoot: pkgs.writeShellApplication {
    name = "eca-git-preparer-commit-policy";
    runtimeInputs = [ pkgs.coreutils pkgs.git pkgs.jq ];
    text = ''
      input=$(cat)
      deny() { jq -n --arg c "$1" '{approval:"deny",additionalContext:$c,systemMessage:"Commit avvist: norsk policy for git-preparer."}'; }
      [ "$(jq -r '.tool_name // ""' <<< "$input")" = eca__git ] || exit 0
      agent=$(jq -r '.agent // ""' <<< "$input"); operation=$(jq -r '.tool_input.operation // ""' <<< "$input")
      command=$(jq -r '.tool_input.command // ""' <<< "$input"); cwd=$(jq -r '.cwd // ""' <<< "$input")
      ro='^(git (status|diff|log|show|rev-parse)|gh (pr|issue|run) (view|diff|list))([[:space:]].*)?$'
      add_re='^git[[:space:]]+add[[:space:]]+--[[:space:]]+[^[:space:]]+$'
      commit_re='(^|[[:space:]])git commit([[:space:]]|$)'
      forbidden='git (push|tag|merge|rebase|reset|clean|branch[[:space:]]+-D|checkout[[:space:]]+--|restore|stash[[:space:]]+(drop|clear)|rm)|git commit .*--amend|gh (pr (create|merge)|release (create|delete|edit))'
      is_add=false; is_commit=false
      [[ "$command" =~ $add_re ]] && is_add=true
      [[ "$command" =~ $commit_re ]] && is_commit=true
      if [[ "$command" =~ $forbidden ]]; then deny "Forbidden Git or GitHub write command."; exit 0; fi
      case "$operation" in
        add)
          [ "$is_add" = true ] || { deny "Operation/command mismatch for staging."; exit 0; }
          [ "$agent" = git-preparer ] || { deny "Only git-preparer may stage through eca__git."; exit 0; }
          ;;
        commit)
          [ "$is_commit" = true ] || { deny "Operation/command mismatch for commit."; exit 0; }
          [ "$agent" = git-preparer ] || { deny "Only git-preparer may commit through eca__git."; exit 0; }
          ;;
        *)
          [[ "$command" =~ $ro ]] && exit 0
          deny "Unknown or write-capable Git command."; exit 0
          ;;
      esac
      if [ "$operation" = add ]; then
        target="''${command#git add -- }"; target="''${target#git add -- }"; valid=true
        case "$target" in
          ""|/*|*:*|*' '*|*$'\n'*|*$'\r'*|*\'*|*\`*|*\$*|*'('*|*')'*|*';'*|*'&'*|*'|'*|*'<'*|*'>'*|*'?'*|*'*'*|*'['*|*']'*|*'{'*|*'}'*|*/./*|./*|*/../*|../*|*/.git|.git|*/.git/*) valid=false;;
        esac
        [ "$valid" = true ] || { deny "Staging requires one safe repository-relative file."; exit 0; }
        real_cwd=$(realpath -e -- "$cwd" 2>/dev/null || true); root=$(git -C "$real_cwd" rev-parse --show-toplevel 2>/dev/null || true); root=$(realpath -e -- "$root" 2>/dev/null || true)
        if [ -z "$real_cwd" ] || [ -z "$root" ]; then deny "Staging cwd is not inside a canonical Git root."; exit 0; fi
        case "$real_cwd" in "$root"|"$root"/*) ;; *) deny "Staging cwd is not inside a canonical Git root."; exit 0;; esac
        candidate=$(realpath -e -- "$real_cwd/$target" 2>/dev/null || realpath -m -- "$real_cwd/$target")
        case "$candidate" in "$root"|"$root"/*) ;; *) deny "Staging target escapes the Git root."; exit 0;; esac
        if [ -e "$candidate" ]; then [ -f "$candidate" ] || { deny "Staging target is not a regular file."; exit 0; }; else git -C "$real_cwd" ls-files --error-unmatch -- "$target" >/dev/null 2>&1 || { deny "Staging target does not exist or is not a tracked deletion."; exit 0; }; fi
        jq -n '{approval:"allow",systemMessage:"Explicit staging authorized for git-preparer."}'; exit 0
      fi
      direct="^(git commit -m '([^']*)'|cd '[^']*' && git commit -m '([^']*)')$"
      exact=false
      if [[ "$command" =~ $direct ]]; then message="''${BASH_REMATCH[2]}"; [ -n "$message" ] || message="''${BASH_REMATCH[3]}"; exact=true; else
        [[ "$command" =~ ^git[[:space:]]+commit[[:space:]]+ ]] || { deny "Commit requires the exact validated form."; exit 0; }
        message=""
      fi
      case "$command" in *'$'*|*'`'*|*';'*|*'|'*|*'<'*|*'>'*) deny "Commit command contains shell metacharacters."; exit 0;; esac
      [ "$exact" = true ] || [[ "$command" != *'&'* ]] || { deny "Commit command contains shell composition."; exit 0; }
      real=$(realpath -e -- "$cwd" 2>/dev/null || true); root=$(git -C "$real" rev-parse --show-toplevel 2>/dev/null || true); root=$(realpath -e -- "$root" 2>/dev/null || true)
      case "$root" in ${protectedRoot}|${protectedRoot}/*) ;; *) jq -n '{approval:"allow",systemMessage:"Verified git-preparer commit authorized."}'; exit 0;; esac
      subject="''${message#*: }"; [[ "$message" =~ ^[a-z][a-z0-9-]*(\([a-z0-9][a-z0-9._/-]*\))?!?:[[:space:]][a-z].*$ ]] && [[ "$subject" =~ ^(legg\ til|fjern|oppdater|rett|tillat|gjør|korriger|refaktorer|forbedre|bruk|støtt|flytt|endre|sikre|håndter|forenkle|dokumenter|test|bygg)[[:space:]]+.+$ ]] && [[ "$subject" != *[[:upper:]]* ]] && [[ "$message" != *. ]] || { deny "Commit message violates the protected Norwegian policy."; exit 0; }
      jq -n '{approval:"allow",systemMessage:"Verified git-preparer commit authorized."}'
    '';
  };

  verify = mkHook "eca-lead-workflow-verify" ''
    input=$(cat); [ "$(jq -r '.agent // ""' <<< "$input")" = lead ] || exit 0; [ "$(jq -r '.follow_up_active // false' <<< "$input")" = true ] && exit 0
    dir=$(state_dir "$(jq -r '.session_id // ""' <<< "$input")" "$(jq -r '.chat_id // ""' <<< "$input")")
    if [ -e "$dir/implementation" ] && [ ! -e "$dir/verifier" ]; then
      [ -e "$dir/nagged-verifier" ] || { : > "$dir/nagged-verifier"; jq -n --arg followUp 'Implementation subagents changed code but `verifier` has not run. Spawn `verifier` now with the exact checks for what changed (e.g. `sbtn test`, `pytest path/to/test.py`, `nix flake check`). If nothing was changed, state that instead.' --arg systemMessage 'Workflow: forcing verification.' '{followUp:$followUp,systemMessage:$systemMessage}'; }
    elif [ -e "$dir/implementation" ] && [ -e "$dir/needs-reviewer" ]; then
      [ -e "$dir/nagged-reviewer" ] || { : > "$dir/nagged-reviewer"; jq -n --arg followUp 'Verification completed. Spawn `reviewer` on the final diff before reporting completion. Also spawn `security` if the change touches auth, secrets, shell execution, permissions, networking, persistence, or user data.' --arg systemMessage 'Workflow: forcing review.' '{followUp:$followUp,systemMessage:$systemMessage}'; }
    elif [ -e "$dir/implementation" ] && [ -e "$dir/verifier" ] && [ -e "$dir/reviewer" ]; then
      if [ -e "$dir/remediation-used" ]; then rm -f "$dir"/{implementation,needs-reviewer,verifier,reviewer,architect,nagged-verifier,nagged-reviewer,remediation-used,remediation-ready}; else : > "$dir/remediation-ready"; rm -f "$dir"/{implementation,needs-reviewer,verifier,reviewer,architect,nagged-verifier,nagged-reviewer}; fi
    fi
  '';
}
