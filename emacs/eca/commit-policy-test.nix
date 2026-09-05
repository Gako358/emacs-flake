{ pkgs, hooks }:
let
  protectedRoot = "/build/eca-commit-policy-fixture";
  hook = hooks.commitPolicy protectedRoot;
in
pkgs.runCommand "eca-commit-policy-test" {
  nativeBuildInputs = [ pkgs.bash pkgs.coreutils pkgs.git pkgs.jq ];
} ''
  set -euo pipefail

  protected="${protectedRoot}"
  nested="$protected/platform/ablanor"
  protected_link="${protectedRoot}-symlink"
  prefixed="${protectedRoot}-similar"
  unrelated="${protectedRoot}-other"
  mkdir -p "$nested" "$prefixed" "$unrelated" "$protected/emacs/eca"
  printf '%s\n' fixture > "$protected/file.nix"
  printf '%s\n' fixture > "$protected/emacs/eca/hooks.nix"
  printf '%s\n' outside > "$unrelated/outside.nix"
  git init -q "$protected"
  git -C "$protected" config user.email test@example.com
  git -C "$protected" config user.name test
  git -C "$protected" add -- file.nix emacs/eca/hooks.nix
  git -C "$protected" commit -qm 'feat: legg til funksjon'
  ln -s "$protected" "$protected_link"
  ln -s "$unrelated/outside.nix" "$protected/outside-link.nix"
  git init -q "$nested"
  git init -q "$prefixed"
  git init -q "$unrelated"

  run_case() {
    name="$1"
    expected="$2"
    cwd="$3"
    operation="$4"
    command="$5"
    input=$(jq -n --arg cwd "$cwd" --arg operation "$operation" --arg command "$command" \
      '{agent:"git-preparer", tool_name:"eca__git", cwd:$cwd,
        tool_input:{operation:$operation, command:$command}}')
    output=$(printf '%s\n' "$input" | ${hook}/bin/eca-git-preparer-commit-policy)
    if [ -z "$output" ] || ! printf '%s' "$output" | jq -e 'type == "object" and (.approval == "allow" or .approval == "deny")' >/dev/null; then
      printf 'FAIL %s: expected explicit policy decision, got %s\n' "$name" "$output" >&2
      exit 1
    fi
    actual=$(printf '%s' "$output" | jq -r '.approval')
    if [ "$actual" != "$expected" ]; then
      printf 'FAIL %s: expected %s, got %s\n%s\n' "$name" "$expected" "$actual" "$output" >&2
      exit 1
    fi
  }

  run_case protected-norwegian allow "$protected" commit "git commit -m 'feat: legg til funksjon'"
  run_case protected-norwegian-scoped allow "$protected" commit "git commit -m 'fix(api): håndter funksjon'"
  run_case protected-norwegian-type allow "$protected" commit "git commit -m 'chore: oppdater funksjon'"
  run_case protected-english deny "$protected" commit "git commit -m 'feat: add feature'"
  run_case protected-uppercase deny "$protected" commit "git commit -m 'feat: Add feature'"
  run_case protected-period deny "$protected" commit "git commit -m 'feat: legg til funksjon.'"
  run_case protected-malformed deny "$protected" commit "git commit -m 'legg til funksjon'"
  run_case protected-file deny "$protected" commit "git commit -F message.txt"
  run_case protected-multiple-m deny "$protected" commit "git commit -m 'feat: legg til en' -m 'funksjon'"
  run_case protected-status deny "$protected" status "git commit -m 'feat: legg til funksjon'"
  run_case protected-dollar-command deny "$protected" commit "git commit -m 'feat: legg til \$(touch /tmp/eca-policy-pwned)'"
  run_case protected-dollar-home deny "$protected" commit "git commit -m 'feat: legg til \$HOME'"
  run_case protected-backtick deny "$protected" commit "git commit -m 'feat: legg til \`uname\`'"
  run_case protected-semicolon deny "$protected" commit "git commit -m 'feat: legg til funksjon'; echo nope"
  run_case protected-ampersand deny "$protected" commit "git commit -m 'feat: legg til funksjon' && echo nope"
  run_case protected-pipe deny "$protected" commit "git commit -m 'feat: legg til funksjon' | cat"
  run_case protected-redirect deny "$protected" commit "git commit -m 'feat: legg til funksjon' > /tmp/nope"
  run_case protected-trailing deny "$protected" commit "git commit -m 'feat: legg til funksjon' trailing"
  run_case protected-quoted-cd allow "$protected" commit "cd '$protected' && git commit -m 'fix(api): håndter funksjon'"
  run_case protected-quoted-cd-english deny "$protected" commit "cd '$protected' && git commit -m 'feat: add feature'"
  run_case protected-relative-cd deny "$protected" commit "cd . && git commit -m 'feat: legg til funksjon'"
  run_case protected-unquoted-cd deny "$protected" commit "cd $protected && git commit -m 'feat: legg til funksjon'"
  run_case protected-git-c deny "$protected" commit "git -C '$protected' commit -m 'feat: legg til funksjon'"
  run_case protected-git-dir deny "$protected" commit "git --git-dir '$protected/.git' commit -m 'feat: legg til funksjon'"
  run_case outside-english allow "$unrelated" commit "git commit -m 'feat: add feature'"
  run_case outside-file allow "$unrelated" commit "git commit -F message.txt"
  run_case outside-redirect deny "$unrelated" commit "git commit -m 'feat: add feature' > /tmp/nope"
  run_case outside-composition deny "$unrelated" commit "git commit -m 'feat: add feature' && echo nope"
  run_case prefixed-outside allow "$prefixed" commit "git commit -m 'feat: add feature'"
  run_case nested-protected deny "$nested" commit "git commit -m 'feat: add feature'"
  run_case symlink-protected deny "$protected_link" commit "git commit -m 'feat: add feature'"

  run_case staging-root allow "$protected" add "git add -- file.nix"
  run_case staging-absolute deny "$protected" add "git add -- $protected/file.nix"
  run_case staging-colon deny "$protected" add "git add -- file:nix"
  run_case staging-directory deny "$protected" add "git add -- emacs"
  run_case staging-nested allow "$protected" add "git add -- emacs/eca/hooks.nix"
  run_case staging-path-dot deny "$protected" add "git add -- emacs/./eca/hooks.nix"
  run_case staging-path-dotdot deny "$protected" add "git add -- emacs/../file.nix"
  run_case staging-nested-traversal deny "$nested" add "git add -- ../../file.nix"
  run_case staging-git deny "$protected" add "git add -- .git"
  run_case staging-outside-symlink deny "$protected" add "git add -- outside-link.nix"
  rm "$protected/file.nix"
  run_case staging-tracked-deletion allow "$protected" add "git add -- file.nix"
  rm "$protected/emacs/eca/hooks.nix"
  run_case staging-nested-tracked-deletion allow "$protected/emacs/eca" add "git add -- hooks.nix"
  run_case staging-dot deny "$protected" add "git add -- ."
  run_case staging-dotdot deny "$protected" add "git add -- .."
  run_case staging-short-option deny "$protected" add "git add -- -A"
  run_case staging-long-option deny "$protected" add "git add -- --all"
  run_case staging-multiple deny "$protected" add "git add -- one.nix two.nix"
  run_case staging-glob deny "$protected" add "git add -- '*.nix'"
  run_case staging-brackets deny "$protected" add "git add -- '[ab].nix'"
  run_case staging-trailing-slash deny "$protected" add "git add -- path/"
  run_case staging-shell-composition deny "$protected" add "git add -- file.nix && echo nope"
  run_case staging-missing-separator deny "$protected" add "git add file.nix"

  forbidden_cases=(
    "git-push|git push origin main"
    "git-tag|git tag v1.0.0"
    "git-merge|git merge feature"
    "git-rebase|git rebase main"
    "git-reset|git reset --hard HEAD"
    "git-clean|git clean -f"
    "git-branch-delete|git branch -D feature"
    "git-checkout|git checkout -- file.nix"
    "git-restore|git restore file.nix"
    "git-stash-drop|git stash drop"
    "git-stash-clear|git stash clear"
    "git-rm|git rm file.nix"
    "git-commit-amend|git commit --amend"
    "gh-pr-create|gh pr create"
    "gh-pr-merge|gh pr merge 1"
    "gh-release-create|gh release create v1.0.0"
    "gh-release-delete|gh release delete v1.0.0"
    "gh-release-edit|gh release edit v1.0.0"
  )
  for forbidden_case in "''${forbidden_cases[@]}"; do
    name="''${forbidden_case%%|*}"; command="''${forbidden_case#*|}"
    run_case "forbidden-$name" deny "$protected" write "$command"
  done

  input=$(jq -n --arg cwd "$protected" --arg command "git add -- file.nix" \
    '{agent:"not-git-preparer",tool_name:"eca__git",cwd:$cwd,tool_input:{operation:"add",command:$command}}')
  output=$(printf '%s\n' "$input" | ${hook}/bin/eca-git-preparer-commit-policy)
  [ "$(printf '%s' "$output" | jq -r '.approval')" = deny ] || { echo 'FAIL wrong-agent staging' >&2; exit 1; }
  input=$(jq -n --arg cwd "$protected" --arg command "git add -- file.nix" \
    '{agent:"git-preparer",tool_name:"other-tool",cwd:$cwd,tool_input:{operation:"add",command:$command}}')
  [ -z "$(printf '%s\n' "$input" | ${hook}/bin/eca-git-preparer-commit-policy)" ] || { echo 'FAIL wrong-tool staging' >&2; exit 1; }

  input=$(jq -n --arg cwd "$protected" --arg command "git commit -m 'feat: legg til funksjon'" \
    '{agent:"not-git-preparer",tool_name:"eca__git",cwd:$cwd,tool_input:{operation:"commit",command:$command}}')
  output=$(printf '%s\n' "$input" | ${hook}/bin/eca-git-preparer-commit-policy)
  [ "$(printf '%s' "$output" | jq -r '.approval')" = deny ] || { echo 'FAIL wrong-agent commit' >&2; exit 1; }
  case "$(printf '%s' "$output" | jq -r '.additionalContext')" in
    'Only git-preparer may commit through eca__git'*) ;;
    *) echo 'FAIL wrong-agent commit message' >&2; exit 1 ;;
  esac
  input=$(jq -n --arg cwd "$protected" --arg command "git status" \
    '{agent:"not-git-preparer",tool_name:"eca__git",cwd:$cwd,tool_input:{operation:"status",command:$command}}')
  [ -z "$(printf '%s\n' "$input" | ${hook}/bin/eca-git-preparer-commit-policy)" ] || { echo 'FAIL wrong-agent non-commit' >&2; exit 1; }
  input=$(jq -n --arg cwd "$protected" --arg command "git commit -m 'feat: legg til funksjon'" \
    '{agent:"git-preparer",tool_name:"other-tool",cwd:$cwd,tool_input:{operation:"commit",command:$command}}')
  [ -z "$(printf '%s\n' "$input" | ${hook}/bin/eca-git-preparer-commit-policy)" ] || { echo 'FAIL wrong-tool' >&2; exit 1; }

  touch "$out"
''
