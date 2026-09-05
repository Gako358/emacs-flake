{ pkgs, hooks }:
let
  gate = hooks.gate;
  record = hooks.record;
  verify = hooks.verify;
  solo = builtins.readFile ./agents/solo.md;
in
assert pkgs.lib.hasInfix "mode: primary" solo;
assert pkgs.lib.hasInfix "model: github-copilot/gpt-5.6-sol" solo;
assert pkgs.lib.hasInfix "  - git" solo;
assert pkgs.lib.hasInfix "  - spawn_agent" solo;
pkgs.runCommand "eca-workflow-hooks-test" {
  nativeBuildInputs = [ pkgs.bash pkgs.coreutils pkgs.jq ];
} ''
  set -euo pipefail
  session="workflow-test-$$"; chat="chat"
  state="''${XDG_RUNTIME_DIR:-/tmp}/eca-lead-workflow/$session/$chat"
  second_session="workflow-test-second-$$"; second_chat="second-chat"
  second_state="''${XDG_RUNTIME_DIR:-/tmp}/eca-lead-workflow/$second_session/$second_chat"
  same_session="workflow-test-isolated-$$"; same_session_first_chat="first-chat"; same_session_second_chat="second-chat"
  same_session_first_state="''${XDG_RUNTIME_DIR:-/tmp}/eca-lead-workflow/$same_session/$same_session_first_chat"
  same_session_second_state="''${XDG_RUNTIME_DIR:-/tmp}/eca-lead-workflow/$same_session/$same_session_second_chat"
  different_session_first="workflow-test-isolated-first-$$"; different_session_second="workflow-test-isolated-second-$$"; different_session_chat="same-chat"
  different_session_first_state="''${XDG_RUNTIME_DIR:-/tmp}/eca-lead-workflow/$different_session_first/$different_session_chat"
  different_session_second_state="''${XDG_RUNTIME_DIR:-/tmp}/eca-lead-workflow/$different_session_second/$different_session_chat"
  rm -rf "$state" "$second_state" "$same_session_first_state" "$same_session_second_state" "$different_session_first_state" "$different_session_second_state"; export session chat
  verifier_follow_up='Implementation subagents changed code but `verifier` has not run. Spawn `verifier` now with the exact checks for what changed (e.g. `sbtn test`, `pytest path/to/test.py`, `nix flake check`). If nothing was changed, state that instead.'
  reviewer_follow_up='Verification completed. Spawn `reviewer` on the final diff before reporting completion. Also spawn `security` if the change touches auth, secrets, shell execution, permissions, networking, persistence, or user data.'
  input() { jq -n --arg agent "$1" --arg target "$2" --arg task "''${3:-}" '{agent:$agent,session_id:$ENV.session,chat_id:$ENV.chat,tool_input:{agent:$target,task:$task}}'; }
  followup_input() { jq -n --arg session "$1" --arg chat "$2" --arg target "$3" '{agent:"lead",session_id:$session,chat_id:$chat,follow_up_active:true,tool_input:{agent:$target,task:"implementation"}}'; }
  test -z "$(followup_input "$session" "$chat" backend | ${gate}/bin/eca-lead-workflow-gate)"
  test ! -e "$state"
  test "$(input lead backend implement | ${gate}/bin/eca-lead-workflow-gate | jq -r .approval)" = deny
  input lead architect plan | ${record}/bin/eca-lead-workflow-record
  input lead backend implement | ${record}/bin/eca-lead-workflow-record
  jq -n --arg session "$same_session" --arg chat "$same_session_first_chat" '{agent:"lead",session_id:$session,chat_id:$chat,tool_input:{agent:"architect",task:"plan"}}' | ${record}/bin/eca-lead-workflow-record
  jq -n --arg session "$same_session" --arg chat "$same_session_first_chat" '{agent:"lead",session_id:$session,chat_id:$chat,tool_input:{agent:"backend",task:"implementation"}}' | ${record}/bin/eca-lead-workflow-record
  jq -n --arg session "$same_session" --arg chat "$same_session_first_chat" '{agent:"lead",session_id:$session,chat_id:$chat,tool_input:{agent:"verifier",task:"nix flake check"}}' | ${record}/bin/eca-lead-workflow-record
  test "$(jq -n --arg session "$same_session" --arg chat "$same_session_second_chat" '{agent:"lead",session_id:$session,chat_id:$chat,tool_input:{agent:"backend",task:"implementation"}}' | ${gate}/bin/eca-lead-workflow-gate | jq -r .approval)" = deny
  test "$(jq -n --arg session "$same_session" --arg chat "$same_session_second_chat" '{agent:"lead",session_id:$session,chat_id:$chat,tool_input:{agent:"reviewer",task:"review"}}' | ${gate}/bin/eca-lead-workflow-gate | jq -r .approval)" = deny
  test ! -e "$same_session_second_state/architect"; test ! -e "$same_session_second_state/implementation"; test ! -e "$same_session_second_state/verifier"; test ! -e "$same_session_second_state/reviewer"
  jq -n --arg session "$different_session_first" --arg chat "$different_session_chat" '{agent:"lead",session_id:$session,chat_id:$chat,tool_input:{agent:"architect",task:"plan"}}' | ${record}/bin/eca-lead-workflow-record
  jq -n --arg session "$different_session_first" --arg chat "$different_session_chat" '{agent:"lead",session_id:$session,chat_id:$chat,tool_input:{agent:"backend",task:"implementation"}}' | ${record}/bin/eca-lead-workflow-record
  jq -n --arg session "$different_session_first" --arg chat "$different_session_chat" '{agent:"lead",session_id:$session,chat_id:$chat,tool_input:{agent:"verifier",task:"nix flake check"}}' | ${record}/bin/eca-lead-workflow-record
  test "$(jq -n --arg session "$different_session_second" --arg chat "$different_session_chat" '{agent:"lead",session_id:$session,chat_id:$chat,tool_input:{agent:"backend",task:"implementation"}}' | ${gate}/bin/eca-lead-workflow-gate | jq -r .approval)" = deny
  test "$(jq -n --arg session "$different_session_second" --arg chat "$different_session_chat" '{agent:"lead",session_id:$session,chat_id:$chat,tool_input:{agent:"reviewer",task:"review"}}' | ${gate}/bin/eca-lead-workflow-gate | jq -r .approval)" = deny
  test ! -e "$different_session_second_state/architect"; test ! -e "$different_session_second_state/implementation"; test ! -e "$different_session_second_state/verifier"; test ! -e "$different_session_second_state/reviewer"
  test "$(input lead verifier 'check things' | ${gate}/bin/eca-lead-workflow-gate | jq -r .approval)" = deny
  test -z "$(input lead verifier 'run nix flake check' | ${gate}/bin/eca-lead-workflow-gate)"
  input lead verifier 'run nix flake check' | ${record}/bin/eca-lead-workflow-record
  output=$(input lead lead done | ${verify}/bin/eca-lead-workflow-verify)
  test "$(printf '%s' "$output" | jq -r .followUp)" = "$reviewer_follow_up"
  test "$(printf '%s' "$output" | jq -r .systemMessage)" = 'Workflow: forcing review.'
  test -e "$state/nagged-reviewer"; test ! -e "$state/remediation-ready"
  input lead reviewer review | ${record}/bin/eca-lead-workflow-record
  test -z "$(input lead lead done | ${verify}/bin/eca-lead-workflow-verify)"
  test -e "$state/remediation-ready"
  test ! -e "$state/architect"; test ! -e "$state/implementation"; test ! -e "$state/verifier"
  test ! -e "$state/reviewer"; test ! -e "$state/needs-reviewer"
  test "$(jq -n --arg session "$second_session" --arg chat "$second_chat" '{agent:"lead",session_id:$session,chat_id:$chat,tool_input:{agent:"reviewer",task:"review"}}' | ${gate}/bin/eca-lead-workflow-gate | jq -r .approval)" = deny
  remediation=$(input lead backend 'consolidated remediation of findings' | ${gate}/bin/eca-lead-workflow-gate)
  test -z "$remediation"; test -e "$state/remediation-used"; test ! -e "$state/remediation-ready"
  input lead backend 'consolidated remediation of findings' | ${record}/bin/eca-lead-workflow-record
  test -e "$state/implementation"; test ! -e "$state/verifier"
  followup_input() { jq -n --arg session "$1" --arg chat "$2" --arg target "$3" '{agent:"lead",session_id:$session,chat_id:$chat,follow_up_active:true,tool_input:{agent:$target,task:"implementation"}}'; }
  test -z "$(followup_input "$session" "$chat" frontend | ${record}/bin/eca-lead-workflow-record)"; test ! -e "$state/frontend"
  test -z "$(followup_input "$session" "$chat" backend | ${verify}/bin/eca-lead-workflow-verify)"; test ! -e "$state/nagged-verifier"
  output=$(input lead lead done | ${verify}/bin/eca-lead-workflow-verify)
  test "$(printf '%s' "$output" | jq -r .followUp)" = "$verifier_follow_up"
  test "$(printf '%s' "$output" | jq -r .systemMessage)" = 'Workflow: forcing verification.'
  test -e "$state/nagged-verifier"
  input lead verifier 'run nix flake check' | ${record}/bin/eca-lead-workflow-record
  output=$(input lead lead done | ${verify}/bin/eca-lead-workflow-verify)
  test "$(printf '%s' "$output" | jq -r .followUp)" = "$reviewer_follow_up"
  test "$(printf '%s' "$output" | jq -r .systemMessage)" = 'Workflow: forcing review.'
  input lead reviewer review | ${record}/bin/eca-lead-workflow-record
  test -z "$(input lead lead done | ${verify}/bin/eca-lead-workflow-verify)"
  test ! -e "$state/implementation"; test ! -e "$state/remediation-used"; test ! -e "$state/remediation-ready"
  test ! -e "$state/architect"; test ! -e "$state/verifier"; test ! -e "$state/reviewer"
  test ! -e "$state/needs-reviewer"; test ! -e "$state/nagged-verifier"; test ! -e "$state/nagged-reviewer"
  test "$(jq -n --arg session "$second_session" --arg chat "$second_chat" '{agent:"lead",session_id:$session,chat_id:$chat,tool_input:{agent:"backend",task:"implementation"}}' | ${gate}/bin/eca-lead-workflow-gate | jq -r .approval)" = deny
  test ! -e "$second_state/implementation"
  touch "$out"
''
