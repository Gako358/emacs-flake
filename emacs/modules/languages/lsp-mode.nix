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
    (lsp-diagnostics-provider :flymake)
    (lsp-headerline-breadcrumb-enable t)
    (lsp-enable-snippet nil))

  (use-package lsp-ui
    :ensure t
    :after lsp-mode
    :custom
    (lsp-ui-doc-enable t)
    (lsp-ui-sideline-enable t)
    (lsp-ui-peek-enable t))
  '';
}
