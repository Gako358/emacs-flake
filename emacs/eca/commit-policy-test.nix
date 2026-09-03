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
  mkdir -p "$nested" "$prefixed" "$unrelated"
  git init -q "$protected"
  ln -s "$protected" "$protected_link"
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
    if [ -n "$output" ]; then
      actual=$(printf '%s' "$output" | jq -r '.approval // "allow"')
    else
      actual=allow
    fi
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

  input=$(jq -n --arg cwd "$protected" --arg command "git commit -m 'feat: legg til funksjon'" \
    '{agent:"not-git-preparer",tool_name:"eca__git",cwd:$cwd,tool_input:{operation:"commit",command:$command}}')
  output=$(printf '%s\n' "$input" | ${hook}/bin/eca-git-preparer-commit-policy)
  [ "$(printf '%s' "$output" | jq -r '.approval')" = deny ] || { echo 'FAIL wrong-agent commit' >&2; exit 1; }
  case "$output" in
    *'Only `git-preparer` may commit through `eca__git'*) ;;
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
