{ pkgs, hooks }:
let
  gate = hooks.gate;
  record = hooks.record;
  verify = hooks.verify;

  expectedAgents = {
    architect = { model = "github-copilot/gpt-6-astra"; variant = "high"; };
    debug = { model = "github-copilot/gpt-5.6-sol"; variant = "high"; };
    lead = { model = "github-copilot/gpt-5.6-sol"; variant = "high"; };
    reviewer = { model = "github-copilot/gpt-5.6-sol"; variant = null; };
    solo = { model = "github-copilot/gpt-5.6-sol"; variant = null; };
    refactorer = { model = "github-copilot/gpt-5.6-sol"; variant = null; };
    backend = { model = "github-copilot/gpt-5.6-luna"; variant = null; };
    frontend = { model = "github-copilot/gpt-5.6-luna"; variant = null; };
    scala = { model = "github-copilot/gpt-5.6-luna"; variant = null; };
    java = { model = "github-copilot/gpt-5.6-luna"; variant = null; };
    researcher = { model = "github-copilot/gpt-5.6-luna"; variant = null; };
    verifier = { model = "github-copilot/gpt-5.6-luna"; variant = null; };
    security = { model = "github-copilot/gemini-3.8-flash"; variant = null; };
    summary = { model = "github-copilot/gpt-4.1"; variant = null; };
    docs = { model = "github-copilot/gpt-4.1"; variant = null; };
  };

  parseFrontmatter = text:
    let
      parts = pkgs.lib.splitString "---" text;
      raw = if builtins.length parts > 1 then builtins.elemAt parts 1 else "";
      lines = pkgs.lib.filter (l: l != "") (pkgs.lib.splitString "\n" raw);
      parseLine = acc: line:
        let pair = pkgs.lib.splitString ": " line;
        in if builtins.length pair == 2 then
          assert !(builtins.hasAttr (builtins.elemAt pair 0) acc);
          acc // { "${pkgs.lib.elemAt pair 0}" = pkgs.lib.elemAt pair 1; }
        else acc;
    in builtins.foldl' parseLine {} lines;

  duplicateModelParseFails = !(builtins.tryEval ((parseFrontmatter "---\nmodel: first\nmodel: second\n---").model)).success;
  validModelParseSucceeds = (parseFrontmatter "---\nmodel: valid\n---").model == "valid";
  agentConfigs = builtins.mapAttrs (name: _:
    let content = builtins.readFile (./agents + "/${name}.md"); frontmatter = parseFrontmatter content;
    in { inherit content frontmatter; mode = frontmatter.mode or null; spawnableBy = frontmatter.spawnableBy or null; model = frontmatter.model or null; variant = frontmatter.variant or null; }
  ) expectedAgents;
  normalize = pkgs.lib.replaceStrings ["\n"] [" "];
  lead = agentConfigs.lead.content;
  leadNorm = normalize lead;
  debug = agentConfigs.debug.content;
  architect = agentConfigs.architect.content;
  researcher = agentConfigs.researcher.content;
  verifier = agentConfigs.verifier.content;
  reviewer = agentConfigs.reviewer.content;
  security = agentConfigs.security.content;
  summary = agentConfigs.summary.content;
  solo = agentConfigs.solo.content;
  globalInstructions = builtins.readFile ./AGENTS.md;
  planningSkill = parseFrontmatter (builtins.readFile ./skills/implementation-planning/SKILL.md);
  behavioralSkill = parseFrontmatter (builtins.readFile ./skills/behavioral-validation/SKILL.md);
  containsAll = text: labels: pkgs.lib.all (label: pkgs.lib.hasInfix label text) labels;
in
assert duplicateModelParseFails;
assert validModelParseSucceeds;
assert pkgs.lib.all (name:
  let expected = expectedAgents.${name}; actual = agentConfigs.${name};
  in actual.model == expected.model && actual.variant == expected.variant
) (builtins.attrNames expectedAgents);
assert !(builtins.hasAttr "git-preparer" expectedAgents);
assert !(pkgs.lib.hasInfix "git-preparer" globalInstructions);
assert agentConfigs.lead.mode == "primary" && agentConfigs.debug.mode == "primary" && agentConfigs.solo.mode == "primary";
assert pkgs.lib.all (name: agentConfigs.${name}.mode == "subagent" && agentConfigs.${name}.spawnableBy == "lead") [
  "architect" "backend" "docs" "frontend" "java" "refactorer" "reviewer" "scala" "security" "summary"
];
assert pkgs.lib.all (agent: containsAll agent [ "spawnableBy:" "  - lead" "  - debug" ]) [ researcher verifier ];
assert containsAll debug [ "observable evidence" "Spawn `researcher`" "deterministic reproduction" "smallest fix" "Spawn `verifier`" "AC-##" "Workstream ID: WF-..." "Task ID: WF-..." "Workflow intent: verification" "Security review: required" "Security review: not-required" "same stable metadata" "one focused remediation pass" "never perform Git writes" ];
assert containsAll lead [ "no agent performs Git writes" "eca__task" "read them back" "repeated `backend`, `scala`, and `java` instances are explicitly allowed" "provisional planning identifiers" "Workflow intent: plan" ];
assert containsAll leadNorm [ "every writable file has one owner" "integration workstream" "Final verifier and reviewer cover the complete integrated change set" ];
assert containsAll lead [ "Security review: required" "Security review: not-required" ];
assert containsAll lead [ "including invocations that produced no file changes" "one consolidated remediation batch" "dispatch all owners together" "rerun security whenever security was required" ];
assert containsAll leadNorm [ "trackers as lifecycle/navigation state" "reports remain the authority for outcomes" ];
assert containsAll researcher [ "curated complete handoff" "current behavior/data flow" "checks/dev shell" "risks/blockers" ];
assert containsAll architect [ "requirement, workstream, task, evidence, and gate registers" "stable fields" "Workstream ID" "Owned files/modules" "Targeted validation" ];
assert containsAll verifier [ "each task and criterion" "literal command" "never infer success" "Overall verdict: PASSED" "Overall verdict: FAILED" "Overall verdict: UNVERIFIED" ];
assert containsAll reviewer [ "Spec" "Standards" "Do not run compile, tests, lint, formatting, typecheck, build, scanners" "Inspect only correctness" "Overall verdict: CLEAR" "Overall verdict: FINDINGS" "Overall verdict: UNVERIFIED" ];
assert containsAll security [ "Inspect only relevant security boundaries" "Do not compile, test, lint, format, typecheck, build, scan" "Report unresolved consequential risks or design flaws to the `lead`" "never escalate directly to the architect" "Overall verdict: CLEAR" "Overall verdict: FINDINGS" "Overall verdict: UNVERIFIED" ];
assert containsAll summary [ "Overall verdict: PASSED" "Overall verdict: CLEAR" "Invocation markers and tracker states are not outcome evidence" ];
assert containsAll (normalize solo) [ "regardless of size" "plan and track the work yourself" "arbitrarily large tasks" "never delegate" "Never perform any git write" ];
assert !(pkgs.lib.hasInfix "maxSteps:" solo);
assert planningSkill.name == "implementation-planning" && (planningSkill.description or "") != "";
assert behavioralSkill.name == "behavioral-validation" && (behavioralSkill.description or "") != "";

pkgs.runCommand "eca-workflow-hooks-test" {
  nativeBuildInputs = [ pkgs.bash pkgs.coreutils pkgs.jq ];
} ''
  set -euo pipefail
  root="''${XDG_RUNTIME_DIR:-/tmp}/eca-lead-workflow-$UID"
  session="workflow-test-$$"; chat="chat"; state="$root/$session/$chat"
  rm -rf "$root/$session"
  export session chat
  task() {
    printf 'AC-01 Workstream ID: WF-01 Task ID: WF-T01 Workflow intent: %s' "$1"
    [ -z "''${2:-}" ] || printf '\n%s' "$2"
  }
  input() { jq -n --arg actor "''${3:-lead}" --arg target "$1" --arg task "$2" '{agent:$actor,session_id:$ENV.session,chat_id:$ENV.chat,tool_input:{agent:$target,task:$task}}'; }
  gate() { input "$1" "$2" | ${gate}/bin/eca-lead-workflow-gate; }
  record() { input "$1" "$2" | ${record}/bin/eca-lead-workflow-record; }
  deny() { result=$(gate "$1" "$2"); test "$(printf '%s' "$result" | jq -r .approval)" = deny; test -n "$(printf '%s' "$result" | jq -r .additionalContext)"; }
  followup() { jq -n --arg s "$1" --arg c "$2" --arg task "$(task implementation)" '{agent:"lead",session_id:$s,chat_id:$c,follow_up_active:true,tool_input:{agent:"backend",task:$task}}'; }

  # Metadata, scope and ordering denials are checked before creating state.
  deny backend "$(task implementation "" | sed 's/AC-01 //')" # missing AC
  deny backend "Workstream ID: WF-01 Task ID: WF-T01 Workflow intent: implementation" # missing AC
  deny backend "AC-01 Task ID: WF-T01 Workflow intent: implementation" # missing workstream
  deny backend "AC-01 Workstream ID: WF-01 Workflow intent: implementation" # missing task
  deny backend "AC-01 Workstream ID: WF-01 Task ID: WF-T01" # missing intent
  deny backend "AC-01 Workstream ID: WF-01 Task ID: WF-T01 Workflow intent: nope" # invalid intent
  deny backend "AC-01 Workstream ID: WF-01 Task ID: WF-T01 Workflow intent: implementation; Workflow intent: integration" # duplicate intent
  deny backend "AC-01 AC-02 Workstream ID: WF-01 Task ID: WF-T01 Workflow intent: implementation" # ambiguous metadata
  deny architect "AC-01 Workstream ID: WF-01 Task ID: WF-T01 Workflow intent: implementation" # mismatch

  # Record independently rejects malformed or unrecognized payloads without creating markers.
  export chat=malformed-record
  record backend "AC-01 Workstream ID: WF-01 Task ID: WF-T01 Workflow intent: review"
  record verifier "$(task verification $'run nix build\nSecurity review: required trailing')"
  record unknown "$(task implementation)"
  test ! -e "$root/$session/$chat/backend-invoked"
  test ! -e "$root/$session/$chat/verifier-invoked"
  test ! -e "$root/$session/$chat/unknown-invoked"
  export chat=chat
  deny verifier "AC-01 Workstream ID: WF-01 Task ID: WF-T01 Workflow intent: verification; Security review: not-required" # no implementation
  deny verifier "AC-01 Workstream ID: WF-01 Task ID: WF-T01 Workflow intent: verification" # no classification
  deny backend "$(task implementation)"
  deny backend "$(task implementation)"
  test -z "$(input solo "$(task implementation)" solo | ${gate}/bin/eca-lead-workflow-gate)"

  record architect "$(task plan)"
  record backend "$(task implementation)"
  deny architect "$(task plan)"
  deny architect "$(task risk)" # risk before verifier
  deny reviewer "$(task review)"
  deny security "$(task security)"
  deny verifier "$(task verification 'run nix flake check')" # classification required
  deny verifier "$(task verification 'Security review: maybe')" # invalid classification
  deny verifier "$(task verification 'Security review: required; Security review: not-required')" # duplicate classification
  deny verifier "$(task verification 'Security review: not-requiredly')" # malformed classification

  # Missing verifier command and then valid per-AC/task evidence requirements.
  deny verifier "$(task verification 'Security review: not-required')"
  record verifier "$(task verification $'run nix flake check\nSecurity review: not-required')"
  output=$(input lead "$(task summary)" | ${verify}/bin/eca-lead-workflow-verify)
  test "$(printf '%s' "$output" | jq -r .systemMessage)" = "Workflow: forcing reviewer invocation."
  test "$(printf '%s' "$output" | jq -r .followUp)" = "Verifier was invoked but reviewer is missing. Spawn reviewer; invoke required security review too. Hooks prove invocation only: inspect actual PASSED/CLEAR/FINDINGS reports."
  test -e "$state/nagged-reviewer"
  record reviewer "$(task review)"
  output=$(input lead "$(task summary)" | ${verify}/bin/eca-lead-workflow-verify)
  test "$(printf '%s' "$output" | jq -r .systemMessage)" = "Workflow: reconcile evidence before remediation or summary."
  test -z "$(gate summary "$(task summary)")"
  record summary "$(task summary)"
  test -e "$state/summary-invoked"

  # A new implementation clears all downstream markers and phase nags.
  record backend "$(task implementation)"
  for marker in verifier-invoked reviewer-invoked security-invoked summary-invoked nagged-verifier nagged-reviewer nagged-security nagged-reconcile; do test ! -e "$state/$marker"; done
  deny architect "$(task plan)"

  # Required security forces reviewer, security, then reconciliation; summary waits for security.
  record verifier "$(task verification $'run nix build .#check\nSecurity review: required')"
  output=$(input lead "$(task summary)" | ${verify}/bin/eca-lead-workflow-verify)
  test "$(printf '%s' "$output" | jq -r .systemMessage)" = "Workflow: forcing reviewer invocation."
  record reviewer "$(task review)"
  output=$(input lead "$(task summary)" | ${verify}/bin/eca-lead-workflow-verify)
  test "$(printf '%s' "$output" | jq -r .systemMessage)" = "Workflow: forcing security invocation."
  test "$(gate summary "$(task summary)" | jq -r .approval)" = deny
  record security "$(task security)"
  output=$(input lead "$(task summary)" | ${verify}/bin/eca-lead-workflow-verify)
  test "$(printf '%s' "$output" | jq -r .systemMessage)" = "Workflow: reconcile evidence before remediation or summary."
  test -z "$(gate summary "$(task summary)")"
  record summary "$(task summary)"
  test -e "$state/summary-invoked"
  test -z "$(input lead "$(task summary)" | ${verify}/bin/eca-lead-workflow-verify)"

  # A post-summary architect plan resets the completed workflow and remains initially eligible.
  test -z "$(gate architect "$(task plan)")"
  record architect "$(task plan)"
  test -e "$state/architect-invoked"
  for marker in implementation-invoked verifier-invoked reviewer-invoked security-invoked summary-invoked security-required remediation-used; do test ! -e "$state/$marker"; done
  test -z "$(gate backend "$(task implementation)")"
  record backend "$(task implementation)"
  record verifier "$(task verification $'run nix build .#check\nSecurity review: required')"
  record reviewer "$(task review)"
  record security "$(task security)"

  # A later not-required verifier classification preserves sticky required security state.
  record backend "$(task remediation)"
  record verifier "$(task verification $'run nix build .#check\nSecurity review: not-required')"
  test -e "$state/security-required"

  # Summary recording is not an outcome and does not clear state. Review blocks ordinary implementation;
  # one remediation pass is allowed only after all required invocations, and the second is denied.
  deny backend "$(task implementation)"
  deny backend "$(task remediation)"
  record backend "$(task remediation)"
  test -e "$state/remediation-used"
  for marker in verifier-invoked reviewer-invoked security-invoked summary-invoked; do test ! -e "$state/$marker"; done
  for specialist in backend frontend scala java refactorer docs; do
    deny "$specialist" "$(task implementation)"
    deny "$specialist" "$(task integration)"
    deny "$specialist" "$(task remediation)"
  done
  deny architect "$(task risk)"
  touch "$state/verifier-invoked"
  deny backend "$(task implementation)"
  deny architect "$(task risk)"

  # Parallel remediation pre-hooks reserve each domain atomically: duplicates lose, distinct domains share the batch.
  export session="workflow-remediation-race-$$" chat=chat
  record architect "$(task plan)"
  record backend "$(task implementation)"
  record verifier "$(task verification $'run nix build .#check\nSecurity review: not-required')"
  record reviewer "$(task review)"
  remediation_followup=$(followup "$session" "$chat" backend | jq '.tool_input.task = ("AC-01 Workstream ID: WF-01 Task ID: WF-T01 Workflow intent: remediation")')
  test -z "$(printf '%s' "$remediation_followup" | ${gate}/bin/eca-lead-workflow-gate)"
  deny backend "$(task remediation)"
  test -z "$(gate frontend "$(task remediation)")"
  test -d "$root/$session/$chat/remediation-dispatch/backend"
  test -d "$root/$session/$chat/remediation-dispatch/frontend"
  record backend "$(task remediation)"
  deny scala "$(task remediation)"

  # Repeated implementation specialists remain valid in an initial, isolated workflow.
  for specialist in backend scala java; do
    s="workflow-repeat-$$-$specialist"; c=chat; export session="$s" chat="$c"
    record architect "$(task plan)"
    test -z "$(gate "$specialist" "$(task implementation)")"
  done
  export session="workflow-test-$$" chat=other-chat
  record architect "$(task plan)"
  test -z "$(gate backend "$(task implementation)")"
  test ! -e "$root/$session/$chat/implementation-invoked"
  invalid_followup=$(followup "$session" "$chat" backend | jq '.tool_input.task = ("AC-01 Workstream ID: WF-01 Task ID: WF-T01 Workflow intent: integration")')
  test "$(printf '%s' "$invalid_followup" | ${gate}/bin/eca-lead-workflow-gate | jq -r .approval)" = deny
  valid_followup=$(followup "$session" "$chat" backend | jq '.tool_input.task = ("AC-01 Workstream ID: WF-01 Task ID: WF-T01 Workflow intent: implementation")')
  test -z "$(printf '%s' "$valid_followup" | ${record}/bin/eca-lead-workflow-record)"
  test -e "$root/$session/$chat/backend-invoked"
  touch "$out"
''
