_:
{
  order = 1301;
  elisp = ''
    ;;; LSP-Mode
  ;; LSP Mode
  (use-package lsp-mode
    :ensure t
    :commands (lsp lsp-deferred)
    :init
    (setq lsp-keymap-prefix "C-c l")
    :custom
    (lsp-idle-delay 0.500)
    (lsp-log-io nil)
    (lsp-completion-provider :none)
    (lsp-headerline-breadcrumb-enable t)
    (lsp-enable-snippet nil)
    :config
    (evil-leader/set-key
      "lo" 'lsp
      "lq" 'lsp-workspace-shutdown
      "la" 'lsp-execute-code-action
      "lf" 'apheleia-format-buffer
      "lr" 'lsp-rename
      "lR" 'lsp-workspace-restart
      "lH" 'lsp-inlay-hints-mode
      "ld" 'lsp-find-definition
      "li" 'lsp-find-implementation
      "lt" 'lsp-find-type-definition
      "lI" 'lsp-organize-imports
      "ln" 'flycheck-next-error
      "lp" 'flycheck-previous-error
      "ll" 'flycheck-list-errors))

  (use-package lsp-ui
    :ensure t
    :after lsp-mode
    :custom
    (lsp-ui-doc-enable t)
    (lsp-ui-sideline-enable t)
    (lsp-ui-peek-enable t)
    :config
    (evil-leader/set-key
      "lh" 'lsp-ui-doc-glance))
  '';
}
