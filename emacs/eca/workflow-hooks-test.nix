{ pkgs, hooks }:
let
  gitApproval = hooks.gitApproval;
  gate = hooks.gate;
  record = hooks.record;
  verify = hooks.verify;

  expectedAgents = {
    remediator = {
      model = "github-copilot/gpt-5.6-sol";
      variant = "high";
    };
    architect = {
      model = "github-copilot/gpt-6-astra";
      variant = "high";
    };
    designer = {
      model = "github-copilot/gpt-5.6-sol";
      variant = "high";
    };
    debug = {
      model = "github-copilot/gpt-6-astra";
      variant = "high";
    };
    lead = {
      model = "github-copilot/gpt-5.6-sol";
      variant = "high";
    };
    reviewer = {
      model = "github-copilot/claude-opus-5";
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
      model = "github-copilot/gpt-5.3-codex";
      variant = null;
    };
    frontend = {
      model = "github-copilot/gpt-5.3-codex";
      variant = null;
    };
    scala = {
      model = "github-copilot/gpt-5.3-codex";
      variant = null;
    };
    java = {
      model = "github-copilot/gpt-5.3-codex";
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
      model = "github-copilot/gpt-5.6-sol";
      variant = null;
    };
    version = {
      model = "github-copilot/gpt-5.6-sol";
      variant = "high";
    };
    security = {
      model = "github-copilot/claude-sonnet-5";
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
  remediator = agentConfigs.remediator.content;
  summary = agentConfigs.summary.content;
  solo = agentConfigs.solo.content;
  globalInstructions = builtins.readFile ./AGENTS.md;
  ecaModule = import ../modules/completion/eca.nix { };
  emacsModule = builtins.readFile ../default.nix;
  planningSkill = parseFrontmatter (builtins.readFile ./skills/implementation-planning/SKILL.md);
  behavioralSkill = parseFrontmatter (builtins.readFile ./skills/behavioral-validation/SKILL.md);
  githubSkill = parseFrontmatter (builtins.readFile ./skills/github/SKILL.md);
  containsAll = text: labels: pkgs.lib.all (label: pkgs.lib.hasInfix label text) labels;
  ecaElisp = ecaModule.elisp;
  privateChatRegression = pkgs.writeText "eca-private-chat-regression.el" ''
    (require 'ert)
    (defvar calls nil)
    (defvar my/eca-chat-custom-agent nil)
    (defvar my/eca-chat-custom-model nil)
    (defvar eca-chat--selected-variant nil)
    (defvar regression-buffer (generate-new-buffer " *eca-regression*"))
    (defun eca-session () t)
    (defun eca-assert-session-running (_session) nil)
    (defun eca-chat--new-chat (_session) nil)
    (defun eca-chat--get-last-buffer (_session) regression-buffer)
    (defun eca-chat--set-prompt (prompt) (setq calls prompt))
    (defun load-production-form (source symbol)
      (with-temp-buffer
        (insert-file-contents source)
        (goto-char (point-min))
        (let (form)
          (while (and (not form) (not (eobp)))
            (let ((candidate (read (current-buffer))))
              (when (and (listp candidate)
                         (memq (car candidate) '(defconst defun))
                         (eq (cadr candidate) symbol))
                (setq form candidate))))
          (unless form
            (error "Production form not found: %s" symbol))
          form)))
    (dolist (symbol '(my/eca-private-routing-prompts
                      my/eca--new-agent-chat
                      my/eca-private-chat))
      (eval (load-production-form "${pkgs.writeText "eca-production.el" ecaElisp}" symbol)))
    (ert-deftest private-routing-complete-tuples ()
      (dolist (expected
               '(("lead" "anthropic/claude-opus-5" "high")
                 ("remediator" "anthropic/claude-opus-5" "high")
                 ("designer" "anthropic/claude-opus-5" "high")
                 ("debug" "anthropic/claude-opus-5" "high")
                 ("solo" "anthropic/claude-opus-5" nil)
                 ("version" "anthropic/claude-opus-5" "high")
                 ("docs" "anthropic/claude-haiku-4-5-20251001" nil)))
        (pcase-let ((`(,agent ,model ,variant) expected))
          (with-current-buffer regression-buffer
            (setq calls nil
                  eca-chat-custom-agent nil
                  eca-chat-custom-model nil
                  eca-chat--selected-variant nil))
          (my/eca-private-chat agent)
          (with-current-buffer regression-buffer
            (should (equal (buffer-local-value 'eca-chat-custom-agent regression-buffer) agent))
            (should (equal (buffer-local-value 'eca-chat-custom-model regression-buffer) model))
            (should (equal (buffer-local-value 'eca-chat--selected-variant regression-buffer) variant))
            (should (equal (buffer-local-value 'calls regression-buffer)
                           (alist-get agent my/eca-private-routing-prompts nil nil #'equal)))))))
    (ert-run-tests-batch-and-exit)
  '';
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
    "remediator"
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
  "requirement, section, workstream, task, evidence, and gate registers"
  "ordered top-level implementation section"
  "current continuation point"
  "update a section to `IN_PROGRESS`"
  "Security review is required at every section checkpoint"
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
assert containsAll leadNorm [
  "including invocations that produced no file changes"
  "Dispatch `remediator` only"
  "Dispatch all eligible remediators in one parallel `eca__spawn_agent` message"
  "A malformed or unusable remediator invocation is retried with the same remediator and stable Task ID; do not disguise retries"
];
assert containsAll leadNorm [
  "implementation discoveries"
  "When the architect replans"
  "Reinvoke `architect`"
  "Keep verifier preceding re-entry"
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
  "exactly one implementation section at a time"
  "update that section in the Org plan to `IN_PROGRESS`"
  "Security review is required for every section checkpoint"
  "update the plan section to `PASSED`"
  "Persist that plan update before asking the user whether to continue or stop"
  "leave later sections `PENDING`"
  "Resume at the first non-`PASSED` section"
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
assert containsAll ecaElisp [
  "(\"lead\" . \"Use the private Anthropic model profile"
  "- remediator: anthropic/claude-opus-5, high"
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
assert !(pkgs.lib.hasInfix "lead-workflow-gate =" ecaElisp);
assert pkgs.lib.hasInfix "builtins.toJSON { roots = cfg.eca.nixMcp.roots; }" emacsModule;
assert containsAll emacsModule [
  "nix__develop"
  "nix__run"
  "nix__sbt"
];
assert planningSkill.name == "implementation-planning" && (planningSkill.description or "") != "";
assert containsAll (builtins.readFile ./skills/implementation-planning/SKILL.md) [
  "requirements, sections, workstreams, tasks, evidence, and gates"
  "ordered, resumable sections"
  "continue-or-stop checkpoint"
];
assert behavioralSkill.name == "behavioral-validation" && (behavioralSkill.description or "") != "";
assert githubSkill.name == "github" && (githubSkill.description or "") != "";
assert containsAll (builtins.readFile ./skills/nix/SKILL.md) [
  "pure and lockfile-driven by default"
  "`nix__run`"
  "every supported `nix run`"
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
assert containsAll remediator [
  "lead-only remediator"
  "Do not spawn agents or perform Git writes"
  "exactly one bounded consolidated remediation batch"
  "explicit ownership release/transfer"
  "disjoint bounded affected paths"
  "reviewer/security-only assignments"
  "return BLOCKED and require refusal/replanning instead"
  "supplemental within paths already transferred"
  "cannot establish eligibility or expand the transferred paths"
];
assert containsAll leadNorm [
  "Dispatch `remediator` only"
  "Every remediation manifest records Task ID"
  "consolidate findings and assign every actionable finding to its planned named specialist"
  "consolidation and assignment do not themselves establish remediator eligibility"
  "Remediator eligibility derives exclusively from actionable FAILED implementation findings in the latest actual verifier report"
  "historical or stable Finding ID cannot establish eligibility unless the latest actual verifier report re-emits that ID as an actionable FAILED implementation finding"
  "Overall FAILED, UNVERIFIED"
  "Reviewer/security-only findings remain with their planned named owner"
  "cannot independently trigger remediator"
  "supplemental obligations only when explicitly enumerated inside paths already transferred"
  "Conflicts or missing attribution or ownership stop dispatch and require replanning"
  "same remediator and stable Task ID"
  "Continue without a fixed cycle count"
  "latest verifier ends PASSED"
  "all required reviewer/security reports end CLEAR"
];
assert containsAll leadNorm [
  "original specialist exactly one of backend/frontend/scala/java"
  "stable Finding ID"
  "criterion"
  "implementation failure class"
  "affected paths"
  "evidence"
  "attribution rationale"
  "explicitly release prior ownership"
  "assign disjoint affected paths"
  "Task ID, Workstream ID, Original implementation specialist, Current owner"
];
assert containsAll remediator [
  "Do not act on overall failure"
  "UNVERIFIED findings"
  "environment/tooling failures"
  "unknown attribution"
  "missing/conflicting attribution or ownership"
  "return BLOCKED and require refusal/replanning instead"
];
assert containsAll leadNorm [
  "reviewer/security-only findings do not qualify automatically"
  "unknown attribution"
  "environment/tooling"
  "UNVERIFIED"
  "Overall FAILED"
  "every actionable finding"
  "planned named owner"
  "one parallel `eca__spawn_agent` message"
  "same remediator and stable Task ID"
];
assert containsAll verifier [
  "stable Finding ID"
  "failure class"
  "attribution rationale"
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
assert containsAll ecaElisp [
  "(\"docs\" . \"Use the private Anthropic profile with anthropic/claude-haiku-4-5-20251001 and no model substitution."
  "(equal agent \"docs\")"
  "\"anthropic/claude-haiku-4-5-20251001\""
  "nil"
];
assert containsAll agentConfigs.docs.content [
  "documentation artifacts"
  "direct user documentation requests"
  "Do not perform git operations"
];
assert containsAll lead [
  "`docs` for all explicitly requested documentation artifact writing"
  "excluding unsolicited documentation work"
];

pkgs.runCommand "eca-workflow-hooks-test"
  {
    nativeBuildInputs = [
      pkgs.bash
      pkgs.coreutils
      pkgs.jq
      pkgs.emacs
    ];
  }
  ''
    set -euo pipefail
    ${pkgs.emacs}/bin/emacs --batch -Q -l ${privateChatRegression}
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
    invoke_implementation() {
      for marker in verifier-invoked reviewer-invoked security-invoked summary-invoked; do touch "$state/$marker"; done
      record "$1" "$2"
      for marker in verifier-invoked reviewer-invoked security-invoked summary-invoked; do test ! -e "$state/$marker"; done
    }

    # The compatibility gate never denies progress, including malformed recovery calls.
    test -z "$(gate backend 'repair inclusion defects')"
    test -z "$(gate scala 'repair config scheduling')"
    test -z "$(gate verifier 'verify current state')"
    test -z "$(gate general 'recover workflow')"
    test -z "$(input solo 'implementation' solo | ${gate}/bin/eca-lead-workflow-gate)"

    record architect "plan"
    invoke_implementation backend "implementation"
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

    test -z "$(input remediator 'non-lead no-op' remediator | ${record}/bin/eca-lead-workflow-record)"
    test ! -e "$state/remediator-invoked"
    invoke_implementation remediator "remediation batch one"
    test -e "$state/implementation-invoked"
    test ! -e "$state/verifier-invoked"
    record verifier $'rerun affected checks\nSecurity review: required'
    record reviewer review
    record security security
    test -e "$state/security-required"
    test -e "$state/verifier-invoked"
    test -e "$state/reviewer-invoked"
    test -e "$state/security-invoked"
    test ! -e "$state/summary-invoked"

    invoke_implementation scala "planned specialist batch two"
    test -e "$state/implementation-invoked"
    test ! -e "$state/verifier-invoked"
    record verifier $'rerun affected checks\nSecurity review: required'
    record reviewer review
    record security security
    test -e "$state/security-required"
    test -e "$state/verifier-invoked"
    test -e "$state/reviewer-invoked"
    test -e "$state/security-invoked"
    test ! -e "$state/summary-invoked"

    invoke_implementation remediator "remediation batch three"
    test -e "$state/implementation-invoked"
    test ! -e "$state/verifier-invoked"
    record verifier $'rerun affected checks\nSecurity review: required'
    record reviewer review
    record security security
    test -e "$state/security-required"
    test -e "$state/verifier-invoked"
    test -e "$state/reviewer-invoked"
    test -e "$state/security-invoked"

    record summary summary
    test -e "$state/summary-invoked"
    test -z "$(input lead summary | ${verify}/bin/eca-lead-workflow-verify)"

    # A later architect invocation starts fresh without rejecting the invocation.
    record architect plan
    test -e "$state/architect-invoked"
    for marker in implementation-invoked verifier-invoked reviewer-invoked security-invoked summary-invoked security-required; do test ! -e "$state/$marker"; done
    touch "$out"
  ''
