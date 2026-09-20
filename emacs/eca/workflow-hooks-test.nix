{ pkgs, hooks }:
let
  gitApproval = hooks.gitApproval;
  gate = hooks.gate;
  record = hooks.record;
  verify = hooks.verify;

  expectedAgents = {
    architect = {
      model = "github-copilot/gpt-6-astra";
      variant = "high";
    };
    designer = {
      model = "github-copilot/gpt-5.6-sol";
      variant = "high";
    };
    debug = {
      model = "github-copilot/gpt-5.6-sol";
      variant = "high";
    };
    lead = {
      model = "github-copilot/gpt-5.6-sol";
      variant = "high";
    };
    reviewer = {
      model = "github-copilot/gpt-5.6-sol";
      variant = null;
    };
    solo = {
      model = "github-copilot/gpt-5.6-sol";
      variant = null;
    };
    refactorer = {
      model = "github-copilot/gpt-5.6-sol";
      variant = null;
    };
    backend = {
      model = "github-copilot/gpt-5.6-luna";
      variant = null;
    };
    frontend = {
      model = "github-copilot/gpt-5.6-luna";
      variant = null;
    };
    scala = {
      model = "github-copilot/gpt-5.6-luna";
      variant = null;
    };
    java = {
      model = "github-copilot/gpt-5.6-luna";
      variant = null;
    };
    explorer = {
      model = "github-copilot/gpt-5.6-luna";
      variant = null;
    };
    researcher = {
      model = "github-copilot/gpt-5.6-luna";
      variant = null;
    };
    verifier = {
      model = "github-copilot/gpt-5.6-luna";
      variant = null;
    };
    version = {
      model = "github-copilot/gpt-5.6-sol";
      variant = "high";
    };
    security = {
      model = "github-copilot/gemini-3.8-flash";
      variant = null;
    };
    summary = {
      model = "github-copilot/gpt-4.1";
      variant = null;
    };
    docs = {
      model = "github-copilot/gpt-4.1";
      variant = null;
    };
  };
  allExpectedAgents = expectedAgents;
  agentFiles = pkgs.lib.filterAttrs (name: type: type == "regular" && pkgs.lib.hasSuffix ".md" name) (
    builtins.readDir ./agents
  );

  parseFrontmatter =
    text:
    let
      parts = pkgs.lib.splitString "---" text;
      raw = if builtins.length parts > 1 then builtins.elemAt parts 1 else "";
      lines = pkgs.lib.filter (l: l != "") (pkgs.lib.splitString "\n" raw);
      parseLine =
        acc: line:
        let
          pair = pkgs.lib.splitString ": " line;
        in
        if builtins.length pair == 2 then
          assert !(builtins.hasAttr (builtins.elemAt pair 0) acc);
          acc // { "${pkgs.lib.elemAt pair 0}" = pkgs.lib.elemAt pair 1; }
        else
          acc;
    in
    builtins.foldl' parseLine { } lines;

  duplicateModelParseFails =
    !(builtins.tryEval ((parseFrontmatter "---\nmodel: first\nmodel: second\n---").model)).success;
  validModelParseSucceeds = (parseFrontmatter "---\nmodel: valid\n---").model == "valid";
  agentConfigs = builtins.mapAttrs (
    name: _:
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
  ) allExpectedAgents;
  normalize = pkgs.lib.replaceStrings [ "\n" ] [ " " ];
  lead = agentConfigs.lead.content;
  leadNorm = normalize lead;
  debug = agentConfigs.debug.content;
  architect = agentConfigs.architect.content;
  designer = agentConfigs.designer.content;
  researcher = agentConfigs.researcher.content;
  verifier = agentConfigs.verifier.content;
  reviewer = agentConfigs.reviewer.content;
  security = agentConfigs.security.content;
  summary = agentConfigs.summary.content;
  solo = agentConfigs.solo.content;
  globalInstructions = builtins.readFile ./AGENTS.md;
  ecaModule = builtins.readFile ../modules/completion/eca.nix;
  emacsModule = builtins.readFile ../default.nix;
  planningSkill = parseFrontmatter (builtins.readFile ./skills/implementation-planning/SKILL.md);
  behavioralSkill = parseFrontmatter (builtins.readFile ./skills/behavioral-validation/SKILL.md);
  githubSkill = parseFrontmatter (builtins.readFile ./skills/github/SKILL.md);
  containsAll = text: labels: pkgs.lib.all (label: pkgs.lib.hasInfix label text) labels;
in
assert duplicateModelParseFails;
assert validModelParseSucceeds;
assert
  builtins.length (builtins.attrNames agentFiles)
  == builtins.length (builtins.attrNames expectedAgents);
assert pkgs.lib.all (name: builtins.hasAttr "${name}.md" agentFiles) (
  builtins.attrNames expectedAgents
);
assert pkgs.lib.all (
  name:
  let
    expected = allExpectedAgents.${name};
    actual = agentConfigs.${name};
  in
  actual.model == expected.model && actual.variant == expected.variant
) (builtins.attrNames allExpectedAgents);
assert
  agentConfigs.lead.mode == "primary"
  && agentConfigs.debug.mode == "primary"
  && agentConfigs.designer.mode == "primary"
  && agentConfigs.solo.mode == "primary"
  && agentConfigs.version.mode == "primary";
assert pkgs.lib.all
  (name: agentConfigs.${name}.mode == "subagent" && agentConfigs.${name}.spawnableBy == "lead")
  [
    "backend"
    "docs"
    "frontend"
    "java"
    "refactorer"
    "scala"
    "security"
    "summary"
  ];
assert pkgs.lib.all
  (
    agent:
    containsAll agent [
      "spawnableBy:"
      "  - lead"
    ]
  )
  [
    architect
    agentConfigs.explorer.content
    reviewer
    researcher
    verifier
  ];
assert containsAll architect [
  "  - designer"
  "  - version"
  "spawn `explorer`"
  "spawn `verifier`"
  "`reviewer`"
  "designer may invoke you repeatedly"
];
assert containsAll designer [
  "planning-only design agent"
  "exactly one `.org` file in the project root"
  "may spawn only `researcher`, `explorer`, `architect`, and `verifier`"
  "spawn `architect` repeatedly in the same chat"
  "Do not impose a fixed number of planning steps"
  "until the tracked planning work and plan file are complete"
  "requirement, workstream, task, evidence, and gate registers"
  "Do not create or edit any other file"
];
assert containsAll agentConfigs.explorer.content [
  "  - architect"
  "  - designer"
  "Return control to the invoking planner"
];
assert containsAll researcher [
  "  - debug"
  "  - designer"
  "  - version"
];
assert containsAll verifier [
  "  - debug"
  "  - architect"
  "  - designer"
];
assert containsAll reviewer [ "  - architect" ];
assert containsAll agentConfigs.version.content [
  "`github` skill"
  "`researcher`"
  "`architect`"
  "`gh issue create`"
  "Norwegian or English"
  "selected language consistently for the title and body"
  "interactive rebase"
  "cherry-pick"
  "bisect"
  "without per-command approval"
  "--force-with-lease"
];
assert !(pkgs.lib.hasInfix "  - git" agentConfigs.version.content);
assert containsAll globalInstructions [
  "Read-only Git commands may run without confirmation."
  "command-specific approval."
  "`version` agent is exempt"
  "own Git safety"
];
assert containsAll debug [
  "observable evidence"
  "Spawn `researcher`"
  "deterministic reproduction"
  "smallest fix"
  "Spawn `verifier`"
  "AC-##"
  "Workstream ID: WF-..."
  "Task ID: WF-..."
  "Workflow intent: verification"
  "Security review: required"
  "Security review: not-required"
  "same stable metadata"
  "one focused remediation pass"
  "never perform Git writes"
];
assert containsAll lead [
  "including invocations that produced no file changes"
  "one consolidated remediation batch"
  "one parallel `eca__spawn_agent` tool-call message"
  "Do not impose a fixed number of remediation cycles"
  "continue until the tracked plan is complete"
  "Correct malformed metadata and retry"
  "retry under `general`"
  "rerun security whenever security was required"
];
assert containsAll lead [
  "implementation discoveries"
  "When the architect replans"
  "Reinvoke `architect`"
  "Verifier always precedes any reviewer or security re-entry"
];
assert pkgs.lib.all
  (text: !(pkgs.lib.hasInfix "risk pass" text) && !(pkgs.lib.hasInfix "risk assessment" text))
  [
    lead
    architect
  ];
assert containsAll leadNorm [
  "trackers as lifecycle/navigation state"
  "reports remain the authority for outcomes"
];
assert containsAll researcher [
  "curated complete handoff"
  "current behavior/data flow"
  "checks/dev shell"
  "risks/blockers"
];
assert containsAll architect [
  "requirement, workstream, task, evidence, and gate registers"
  "stable fields"
  "Workstream ID"
  "Owned files/modules"
  "Targeted validation"
  "lead may invoke you repeatedly"
];
assert containsAll verifier [
  "each task and criterion"
  "literal command"
  "never infer success"
  "Overall verdict: PASSED"
  "Overall verdict: FAILED"
  "Overall verdict: UNVERIFIED"
];
assert containsAll reviewer [
  "Spec"
  "Standards"
  "Do not run compile, tests, lint, formatting, typecheck, build, scanners"
  "Inspect only correctness"
  "Overall verdict: CLEAR"
  "Overall verdict: FINDINGS"
  "Overall verdict: UNVERIFIED"
];
assert containsAll security [
  "Inspect only relevant security boundaries"
  "Do not compile, test, lint, format, typecheck, build, scan"
  "Report unresolved consequential risks or design flaws to the `lead`"
  "never escalate directly to the architect"
  "Overall verdict: CLEAR"
  "Overall verdict: FINDINGS"
  "Overall verdict: UNVERIFIED"
];
assert containsAll summary [
  "Overall verdict: PASSED"
  "Overall verdict: CLEAR"
  "Invocation markers and tracker states are not outcome evidence"
];
assert containsAll ecaModule [
  "(\"designer\" . \"Use the private Anthropic model profile"
  "- architect: anthropic/claude-opus-5, high"
  "- explorer, researcher, verifier: anthropic/claude-haiku-4-5-20251001"
  "(mapcar #'car my/eca-private-routing-prompts)"
  "\"anthropic/claude-opus-5\""
];
assert containsAll (normalize solo) [
  "regardless of size"
  "plan and track the work yourself"
  "arbitrarily large tasks"
  "never delegate"
  "Never perform any git write"
];
assert pkgs.lib.all (agent: !(pkgs.lib.hasInfix "maxSteps:" agent)) (
  builtins.attrValues (builtins.mapAttrs (_: config: config.content) agentConfigs)
);
assert !(pkgs.lib.hasInfix "lead-workflow-gate =" ecaModule);
assert pkgs.lib.hasInfix "builtins.toJSON { roots = cfg.eca.nixMcp.roots; }" emacsModule;
assert containsAll emacsModule [
  "nix__develop"
  "nix__sbt"
];
assert planningSkill.name == "implementation-planning" && (planningSkill.description or "") != "";
assert behavioralSkill.name == "behavioral-validation" && (behavioralSkill.description or "") != "";
assert githubSkill.name == "github" && (githubSkill.description or "") != "";
assert containsAll (builtins.readFile ./skills/nix/SKILL.md) [
  "pure and lockfile-driven by default"
  "Use `--impure` only when"
  "do not use it to bypass a reproducibility failure"
  "nix__flake_metadata"
  "nix__flake_show"
  "nix__flake_check"
  "nix__eval"
  "nix__build"
  "nix__develop"
  "do not invoke `nix develop` through the shell"
  "Use shell only for other unsupported operations"
  "Never retry a policy-rejected expression or path through shell"
  "--no-write-lock-file"
  "recorded MCP or literal shell evidence before claiming success"
];
assert containsAll verifier [
  "MCP invocation evidence"
  "exact tool name"
  "root/cwd equivalent"
  "structured outcome or exit status"
  "bounded output, truncation, or timeout"
  "PASSED, FAILED, or UNVERIFIED"
  "Missing checklist items, observable proof"
];
assert containsAll (builtins.readFile ./skills/scala-sbt/SKILL.md) [
  "nix__sbt"
  "compile, test, testQuick, scalafixAll, scalafmt, scalafmtAll, and scalafmtCheckAll"
  "Do not run these tasks or `nix develop` through the shell"
];
assert containsAll agentConfigs.scala.content [
  "`scala-sbt` skill"
  "`nix__sbt` workflow"
];
assert containsAll verifier [
  "load the `scala-sbt` skill"
  "`nix__sbt` tasks"
];
assert containsAll (builtins.readFile ./skills/github/SKILL.md) [
  "<type>/<scope>: <imperative summary>"
  "fewest lines"
  "subissues"
  "Example issue"
  "Example subissue"
];

pkgs.runCommand "eca-workflow-hooks-test"
  {
    nativeBuildInputs = [
      pkgs.bash
      pkgs.coreutils
      pkgs.jq
    ];
  }
  ''
    set -euo pipefail
    git_input() { jq -n --arg actor "$1" --arg command "$2" '{agent:$actor,tool_input:{command:$command}}'; }
    git_allow() { result=$(git_input version "$1" | ${gitApproval}/bin/eca-version-git-approval); test "$(printf '%s' "$result" | jq -r .approval)" = allow; }
    git_ask() { test -z "$(git_input "$1" "$2" | ${gitApproval}/bin/eca-version-git-approval)"; }

    git_allow "git pull --rebase origin main"
    git_allow "git rebase -i HEAD~3"
    git_allow "git checkout -b topic"
    git_allow "git cherry-pick abc123"
    git_allow "git bisect start"
    git_allow "git push origin topic"
    git_allow "git push --force-with-lease origin topic"
    git_allow "git reset --hard HEAD~1"
    git_allow "git clean -fdx"
    git_allow "git branch -D topic"
    git_allow "git reflog expire --expire=now --all"
    git_ask version "git pull origin main && git push origin topic"
    git_ask solo "git pull --rebase origin main"

    root="''${XDG_RUNTIME_DIR:-/tmp}/eca-lead-workflow-$UID"
    session="workflow-test-$$"; chat="chat"; state="$root/$session/$chat"
    rm -rf "$root/$session"
    export session chat
    input() { jq -n --arg actor "''${3:-lead}" --arg target "$1" --arg task "$2" '{agent:$actor,session_id:$ENV.session,chat_id:$ENV.chat,tool_input:{agent:$target,task:$task}}'; }
    gate() { input "$1" "$2" | ${gate}/bin/eca-lead-workflow-gate; }
    record() { input "$1" "$2" | ${record}/bin/eca-lead-workflow-record; }

    # The compatibility gate never denies progress, including malformed recovery calls.
    test -z "$(gate backend 'repair inclusion defects')"
    test -z "$(gate scala 'repair config scheduling')"
    test -z "$(gate verifier 'verify current state')"
    test -z "$(gate general 'recover workflow')"
    test -z "$(input solo 'implementation' solo | ${gate}/bin/eca-lead-workflow-gate)"

    record architect "plan"
    record backend "implementation"
    test -e "$state/architect-invoked"
    test -e "$state/implementation-invoked"
    output=$(input lead summary | ${verify}/bin/eca-lead-workflow-verify)
    test "$(printf '%s' "$output" | jq -r .systemMessage)" = "Workflow: continue with verification."

    record verifier $'run nix flake check\nSecurity review: required'
    output=$(input lead summary | ${verify}/bin/eca-lead-workflow-verify)
    test "$(printf '%s' "$output" | jq -r .systemMessage)" = "Workflow: continue with review."
    record reviewer review
    output=$(input lead summary | ${verify}/bin/eca-lead-workflow-verify)
    test "$(printf '%s' "$output" | jq -r .systemMessage)" = "Workflow: continue with security review."
    record security security
    output=$(input lead summary | ${verify}/bin/eca-lead-workflow-verify)
    test "$(printf '%s' "$output" | jq -r .systemMessage)" = "Workflow: continue until the plan is complete."

    # Arbitrarily many remediation cycles remain available and each resets downstream evidence.
    i=0
    while [ "$i" -lt 50 ]; do
      record scala "remediation cycle $i"
      test ! -e "$state/verifier-invoked"
      test ! -e "$state/reviewer-invoked"
      record verifier $'run nix flake check\nSecurity review: not-required'
      record reviewer review
      record security security
      i=$((i + 1))
    done
    test -z "$(gate scala 'remediation cycle 51')"
    test -z "$(gate backend 'remediation cycle 52')"

    record summary summary
    test -e "$state/summary-invoked"
    test -z "$(input lead summary | ${verify}/bin/eca-lead-workflow-verify)"

    # A later architect invocation starts fresh without rejecting the invocation.
    record architect plan
    test -e "$state/architect-invoked"
    for marker in implementation-invoked verifier-invoked reviewer-invoked security-invoked summary-invoked security-required; do test ! -e "$state/$marker"; done
    touch "$out"
  ''
