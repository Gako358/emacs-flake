_:
{
  order = 1302;
  elisp = ''
    ;;; LSP DAP
  (use-package dap-mode
    :ensure t
    :after lsp-mode
    :commands (dap-debug dap-debug-edit-template)
    :custom
    (dap-auto-configure-features
     '(sessions locals breakpoints expressions tooltip controls))
    (dap-breakpoints-file
     (expand-file-name ".cache/dap-breakpoints" user-emacs-directory))
    :config
    (dap-auto-configure-mode 1)

    (require 'dap-java)

    (evil-leader/set-key
      ;; Sessions
      "bd" 'dap-debug                    ; pick + start a launch configuration
      "bl" 'dap-debug-last               ; rerun last configuration
      "bt" 'dap-debug-edit-template      ; create/edit a launch template
      "bq" 'dap-disconnect               ; stop the current session
      ;; Breakpoints
      "bb" 'dap-breakpoint-toggle        ; toggle breakpoint at point
      "bB" 'dap-breakpoint-condition     ; conditional breakpoint
      "bH" 'dap-breakpoint-hit-condition ; hit-count breakpoint
      "bL" 'dap-breakpoint-log-message   ; logpoint (no pause)
      "bx" 'dap-breakpoint-delete-all
      ;; Stepping
      "bn" 'dap-next                     ; step over
      "bi" 'dap-step-in
      "bo" 'dap-step-out
      "bc" 'dap-continue
      "br" 'dap-restart-frame
      ;; Evaluation
      "be" 'dap-eval
      "bE" 'dap-eval-region
      "bT" 'dap-eval-thing-at-point
      ;; UI panes
      "bu" 'dap-ui-locals
      "bw" 'dap-ui-expressions
      "bs" 'dap-ui-sessions
      "bk" 'dap-ui-breakpoints
      "bR" 'dap-ui-repl))
  '';
}
