_:
{
  order = 1801;
  elisp = ''
    ;;; Detached
    (use-package detached
      :init
      (detached-init)
      :bind (([remap async-shell-command] . detached-shell-command)
  	   ([remap compile] . detached-compile)
  	   ([remap recompile] . detached-compile-recompile)
  	   ([remap detached-open-session] . detached-consult-session))
      :custom ((detached-show-output-on-attach t)
  	     (detached-terminal-data-command system-type)
  	     (detached-shell-program "bash")))

    (defun my/detached-run-command-git-root (command)
      "Run COMMAND in the project root directory using detached-shell-command."
      (interactive "sCommand: ")
      (let* ((root-dir (locate-dominating-file default-directory ".git"))
             (default-directory (or root-dir default-directory)))
        (detached-shell-command command)))

    (defun my/detached-run-command-git-root-with-path (path-and-command)
      "Run command in the project root directory using detached-shell-command.
        PATH-AND-COMMAND should be in format 'path command', e.g. 'modules/app npm run dev'.
      The first argument is treated as the relative path from git root, the rest as the command."
      (interactive "sPath and Command: ")
      (let* ((parts (split-string path-and-command " " t))
             (path (car parts))
             (command (string-join (cdr parts) " "))
             (root-dir (locate-dominating-file default-directory ".git"))
             (full-path (and root-dir (expand-file-name path root-dir)))
             (default-directory (or full-path default-directory)))
        (detached-shell-command command)))

    (evil-leader/set-key
      "da" 'detached-attach-session
      "dd" 'detached-detach-session
      "dk" 'detached-kill-session
      "dl" 'detached-list-sessions
      "do" 'detached-open-session
      "dr" 'detached-delete-session
      "dR" 'detached-delete-sessions
      "ds" 'my/detached-run-command-git-root
      "dS" 'my/detached-run-command-git-root-with-path
      "dv" 'detached-view-session
      "dc" 'detached-copy-session-command)
  '';
}
