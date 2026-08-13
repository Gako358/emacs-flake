_:
{
  order = 1908;
  elisp = ''
    ;;; Stacked pull requests
    ;; GitHub's stacked PRs are driven by the first-party `gh-stack'
    ;; extension. Nix puts the binary on the Emacs PATH, so it is called
    ;; directly instead of through `gh stack' -- that avoids having to
    ;; register the extension in gh's mutable data directory.
    ;;
    ;; Everything goes through `compile', which `ghostel-compile-global-mode'
    ;; backs with a real PTY, so the subcommands with a terminal UI
    ;; (`modify', `checkout', `submit') render and accept input.
    ;;
    ;; Forge stays in charge of the plain PR-per-branch flow: its
    ;; `forge-create-pullreq' already asks for the target branch, so a stack
    ;; can also be opened one PR at a time and registered afterwards with
    ;; `my/gh-stack-link'.
    (require 'transient)

    (defun my/gh-stack--root ()
      "Return the top level of the current repository."
      (or (car (ignore-errors
                 (process-lines "git" "rev-parse" "--show-toplevel")))
          (user-error "Not inside a git repository")))

    (defun my/gh-stack--branches ()
      "Return the local branch names of the current repository."
      (let ((default-directory (my/gh-stack--root)))
        (process-lines "git" "for-each-ref" "--format=%(refname:short)"
                       "refs/heads/")))

    (defun my/gh-stack--run (&rest args)
      "Run gh-stack with ARGS from the top level of the current repository."
      (let ((default-directory (my/gh-stack--root))
            (compilation-buffer-name-function (lambda (_) "*gh-stack*")))
        (compile (mapconcat #'shell-quote-argument (cons "gh-stack" args) " "))))

    (defun my/gh-stack-view ()
      "Show the stack the current branch belongs to."
      (interactive)
      (my/gh-stack--run "view"))

    (defun my/gh-stack-init ()
      "Start tracking a stack, rooted at the repository's default branch."
      (interactive)
      (my/gh-stack--run "init"))

    (defun my/gh-stack-add (branch)
      "Create BRANCH on top of the current stack and check it out."
      (interactive "sBranch on top of the stack: ")
      (my/gh-stack--run "add" branch))

    (defun my/gh-stack-modify ()
      "Restructure the stack (drop, fold, insert, rename, reorder)."
      (interactive)
      (my/gh-stack--run "modify"))

    (defun my/gh-stack-submit (&optional auto)
      "Push the stack and create or update its pull requests.
    With a prefix argument AUTO, skip the interactive editor."
      (interactive "P")
      (apply #'my/gh-stack--run "submit" (and auto (list "--auto"))))

    (defun my/gh-stack-sync ()
      "Fetch, restack onto the trunk, force-push and prune merged layers."
      (interactive)
      (my/gh-stack--run "sync"))

    (defun my/gh-stack-rebase ()
      "Cascade a rebase through the branches of the stack."
      (interactive)
      (my/gh-stack--run "rebase"))

    (defun my/gh-stack-link (branches)
      "Register existing BRANCHES, ordered bottom to top, as a stack.
    Reuses the pull requests that already exist and fixes up any base branch
    that does not match the chain, without creating local stack state."
      (interactive
       (list (completing-read-multiple "Branches (bottom to top): "
                                       (my/gh-stack--branches))))
      (apply #'my/gh-stack--run "link" branches))

    (defun my/gh-stack-merge ()
      "Merge the stack, bottom up."
      (interactive)
      (my/gh-stack--run "merge"))

    (defun my/gh-stack-checkout ()
      "Check out a stack by number, pull request or branch."
      (interactive)
      (my/gh-stack--run "checkout"))

    (defun my/gh-stack-switch ()
      "Switch to another branch of the current stack."
      (interactive)
      (my/gh-stack--run "switch"))

    (defun my/gh-stack-down ()
      "Check out the branch below, towards the trunk."
      (interactive)
      (my/gh-stack--run "down"))

    (defun my/gh-stack-up ()
      "Check out the branch above, away from the trunk."
      (interactive)
      (my/gh-stack--run "up"))

    (transient-define-prefix my/gh-stack ()
      "Work with a stack of pull requests."
      ["Stack"
       ("v" "View"            my/gh-stack-view)
       ("i" "Init"            my/gh-stack-init)
       ("a" "Add branch"      my/gh-stack-add)
       ("m" "Modify"          my/gh-stack-modify)]
      ["Remote"
       ("s" "Submit"          my/gh-stack-submit)
       ("y" "Sync"            my/gh-stack-sync)
       ("r" "Rebase"          my/gh-stack-rebase)
       ("l" "Link branches"   my/gh-stack-link)
       ("M" "Merge"           my/gh-stack-merge)]
      ["Navigate"
       ("c" "Checkout"        my/gh-stack-checkout)
       ("w" "Switch"          my/gh-stack-switch)
       ("j" "Down"            my/gh-stack-down)
       ("k" "Up"              my/gh-stack-up)])

    (with-eval-after-load 'magit
      (transient-append-suffix 'magit-dispatch "!"
        '("%" "Stacked PRs" my/gh-stack)))

    (evil-leader/set-key
      "S" 'my/gh-stack)
  '';
}
