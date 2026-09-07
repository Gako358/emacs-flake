{ pkgs, hooks }:
let
  gate = hooks.gate;
  record = hooks.record;
  verify = hooks.verify;

  expectedAgents = {
    architect = { model = "github-copilot/gpt-6-astra"; variant = "high"; };
    lead = { model = "github-copilot/gpt-5.6-sol"; variant = "high"; };
    reviewer = { model = "github-copilot/gpt-5.6-sol"; variant = "high"; };
    solo = { model = "github-copilot/gpt-5.6-sol"; variant = null; };
    refactorer = { model = "github-copilot/gpt-5.6-sol"; variant = null; };
    backend = { model = "github-copilot/gpt-5.6-luna"; variant = null; };
    frontend = { model = "github-copilot/gpt-5.6-luna"; variant = null; };
    scala = { model = "github-copilot/gpt-5.6-luna"; variant = null; };
    java = { model = "github-copilot/gpt-5.6-luna"; variant = null; };
    researcher = { model = "github-copilot/gpt-5.6-luna"; variant = null; };
    verifier = { model = "github-copilot/gpt-5.6-luna"; variant = null; };
    security = { model = "github-copilot/gemini-3.8-flash"; variant = null; };
    docs = { model = "github-copilot/gpt-4.1"; variant = null; };
    git-preparer = { model = "github-copilot/gpt-4.1"; variant = null; };
    release = { model = "github-copilot/gpt-4.1"; variant = null; };
  };

  parseFrontmatter = text:
    let
      parts = pkgs.lib.splitString "---" text;
      rawFrontmatter = if builtins.length parts > 1 then builtins.elemAt parts 1 else "";
      lines = pkgs.lib.filter (l: l != "") (pkgs.lib.splitString "\n" rawFrontmatter);
      parseLine = acc: line:
        let
          pair = pkgs.lib.splitString ": " line;
        in
        if builtins.length pair == 2 then
          assert !(builtins.hasAttr (builtins.elemAt pair 0) acc);
          acc // { "${pkgs.lib.elemAt pair 0}" = pkgs.lib.elemAt pair 1; }
        else
          acc;
    in
    builtins.foldl' parseLine {} lines;

  duplicateModelParseFails = !(builtins.tryEval (
    (parseFrontmatter "---\nmodel: first\nmodel: second\n---").model
  )).success;
  validModelParseSucceeds = (parseFrontmatter "---\nmodel: valid\n---").model == "valid";

  agentConfigs = builtins.mapAttrs (name: _:
    let
      content = builtins.readFile (./agents + "/${name}.md");
      frontmatter = parseFrontmatter content;
    in
    {
      inherit content frontmatter;
      mode = frontmatter.mode or null;
      spawnableBy = frontmatter.spawnableBy or null;
      model = frontmatter.model or null;
      variant = frontmatter.variant or null;
    }
  ) expectedAgents;

  normalizeWs = str: pkgs.lib.replaceStrings ["\n"] [" "] str;

  lead = (agentConfigs.lead).content;
  leadNorm = normalizeWs lead;
  solo = (agentConfigs.solo).content;
  architect = (agentConfigs.architect).content;
  reviewer = (agentConfigs.reviewer).content;

  planningSkill = parseFrontmatter (builtins.readFile ./skills/implementation-planning/SKILL.md);
  behavioralSkill = parseFrontmatter (builtins.readFile ./skills/behavioral-validation/SKILL.md);
in
assert duplicateModelParseFails;
assert validModelParseSucceeds;
assert pkgs.lib.all (name:
  let
    expected = expectedAgents.${name};
    actual = agentConfigs.${name};
  in
  actual.model == expected.model && actual.variant == expected.variant
) (builtins.attrNames expectedAgents);

assert (agentConfigs.lead).mode == "primary";
assert (agentConfigs.solo).mode == "primary";
assert pkgs.lib.all (name:
  let
    cfg = agentConfigs.${name};
  in
  cfg.mode == "subagent" && cfg.spawnableBy == "lead"
) [
  "architect" "backend" "docs" "frontend" "git-preparer" "java"
  "refactorer" "release" "researcher" "reviewer" "scala" "security" "verifier"
];

assert pkgs.lib.hasInfix "  - git" lead;
assert pkgs.lib.hasInfix "  - shell_command" lead;
assert pkgs.lib.hasInfix "  - git" solo;
assert pkgs.lib.hasInfix "  - spawn_agent" solo;

assert pkgs.lib.hasInfix "repeated `backend`, `scala`, and `java` instances are explicitly allowed" leadNorm;
assert pkgs.lib.hasInfix "Spawn independent subagents in parallel in a single message" leadNorm;
assert pkgs.lib.hasInfix "Wait for a group before dependent groups" leadNorm;
assert pkgs.lib.hasInfix "every writable file has one owner" leadNorm;
assert pkgs.lib.hasInfix "integration workstream for shared wiring" leadNorm;
assert pkgs.lib.hasInfix "wait for its completion before spawning reviewer" leadNorm;
assert pkgs.lib.hasInfix "Final verifier and reviewer cover the complete integrated change set" leadNorm;
assert pkgs.lib.hasInfix "`git-preparer` runs only after the combined gates" leadNorm;
assert pkgs.lib.hasInfix "Nix work uses `backend`" leadNorm;

assert pkgs.lib.all (label: pkgs.lib.hasInfix label architect) [
  "Workstream ID"
  "Specialist"
  "Goal"
  "Owned files/modules"
  "Dependencies"
  "Shared interfaces"
  "Parallel group"
  "Integration order"
  "Targeted validation"
];
assert pkgs.lib.hasInfix "Repeated specialists are allowed" architect;
assert pkgs.lib.hasInfix "lower coordination cost than benefit" architect;
assert pkgs.lib.hasInfix "acceptance criteria" architect;
assert pkgs.lib.hasInfix "stop conditions" architect;
assert pkgs.lib.hasInfix "Shared interfaces" architect;

assert pkgs.lib.hasInfix "Spec" reviewer;
assert pkgs.lib.hasInfix "Standards" reviewer;
assert pkgs.lib.hasInfix "original" leadNorm;
assert pkgs.lib.hasInfix "integrated manifest" leadNorm;
assert pkgs.lib.hasInfix "evidence matrix" (agentConfigs.verifier).content;
assert pkgs.lib.hasInfix "PASSED" (agentConfigs.verifier).content;
assert pkgs.lib.hasInfix "FAILED" (agentConfigs.verifier).content;
assert pkgs.lib.hasInfix "UNVERIFIED" (agentConfigs.verifier).content;
assert pkgs.lib.hasInfix "never infer success" (agentConfigs.verifier).content;
assert pkgs.lib.hasInfix "git diff --check" reviewer;
assert pkgs.lib.hasInfix "independently evaluate Spec and Standards" reviewer;
assert pkgs.lib.hasInfix "Do not automatically rerun full suites" reviewer;

assert planningSkill.name == "implementation-planning" && (planningSkill.description or "") != "";
assert behavioralSkill.name == "behavioral-validation" && (behavioralSkill.description or "") != "";

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
  repeated_session="workflow-test-repeated-$$"; repeated_chat="repeated-chat"
  repeated_state="''${XDG_RUNTIME_DIR:-/tmp}/eca-lead-workflow/$repeated_session/$repeated_chat"
  different_session_first="workflow-test-isolated-first-$$"; different_session_second="workflow-test-isolated-second-$$"; different_session_chat="same-chat"
  different_session_first_state="''${XDG_RUNTIME_DIR:-/tmp}/eca-lead-workflow/$different_session_first/$different_session_chat"
  different_session_second_state="''${XDG_RUNTIME_DIR:-/tmp}/eca-lead-workflow/$different_session_second/$different_session_chat"
  rm -rf "$state" "$second_state" "$same_session_first_state" "$same_session_second_state" "$repeated_state" "$different_session_first_state" "$different_session_second_state"; export session chat
  verifier_follow_up='Implementation subagents changed code but `verifier` has not run. Spawn `verifier` now with the exact checks for what changed (e.g. `sbtn test`, `pytest path/to/test.py`, `nix flake check`). If nothing was changed, state that instead.'
  reviewer_follow_up='Verification completed. Spawn `reviewer` on the final diff before reporting completion. Also spawn `security` if the change touches auth, secrets, shell execution, permissions, networking, persistence, or user data.'
  input() { jq -n --arg agent "$1" --arg target "$2" --arg task "''${3:-}" '{agent:$agent,session_id:$ENV.session,chat_id:$ENV.chat,tool_input:{agent:$target,task:$task}}'; }
  followup_input() { jq -n --arg session "$1" --arg chat "$2" --arg target "$3" '{agent:"lead",session_id:$session,chat_id:$chat,follow_up_active:true,tool_input:{agent:$target,task:"implementation"}}'; }
  test -z "$(followup_input "$session" "$chat" backend | ${gate}/bin/eca-lead-workflow-gate)"
  test ! -e "$state"
  test "$(input lead backend implement | ${gate}/bin/eca-lead-workflow-gate | jq -r .approval)" = deny
  input lead architect plan | ${record}/bin/eca-lead-workflow-record
  input lead backend implement | ${record}/bin/eca-lead-workflow-record
  jq -n --arg session "$repeated_session" --arg chat "$repeated_chat" '{agent:"lead",session_id:$session,chat_id:$chat,tool_input:{agent:"architect",task:"plan"}}' | ${record}/bin/eca-lead-workflow-record
  for specialist in backend scala java; do
    jq -n --arg session "$repeated_session" --arg chat "$repeated_chat" --arg specialist "$specialist" '{agent:"lead",session_id:$session,chat_id:$chat,tool_input:{agent:$specialist,task:"implementation"}}' | ${record}/bin/eca-lead-workflow-record
  done
  for specialist in backend scala java; do
    test -z "$(jq -n --arg session "$repeated_session" --arg chat "$repeated_chat" --arg specialist "$specialist" '{agent:"lead",session_id:$session,chat_id:$chat,tool_input:{agent:$specialist,task:"implementation"}}' | ${gate}/bin/eca-lead-workflow-gate)"
  done
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
  input lead architect 'read-only risk assessment' | ${record}/bin/eca-lead-workflow-record
  test -e "$state/architect"
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
