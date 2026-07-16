_:
{
  order = 1300;
  elisp = ''
    ;;; Eglot
      (use-package eglot
        :ensure nil
        :hook ((python-ts-mode . eglot-ensure)
               (nix-ts-mode . eglot-ensure)
               (kotlin-ts-mode . eglot-ensure))
        :custom
        (eglot-autoshutdown t)
        (eglot-events-buffer-config '(:size 100000 :format short))
        :config
        (add-to-list 'eglot-server-programs '(nix-ts-mode . ("nil")))
        (add-to-list 'eglot-server-programs '(kotlin-ts-mode . ("kotlin-language-server"))))

      (defvar my/eglot-modes '(python-ts-mode nix-ts-mode kotlin-ts-mode)
        "Major modes managed by eglot; everything else uses lsp-mode.")

      (defun my/lsp-dispatch (eglot-cmd lsp-cmd)
        (cond ((bound-and-true-p eglot--managed-mode) (call-interactively eglot-cmd))
              ((bound-and-true-p lsp-managed-mode) (call-interactively lsp-cmd))
              (t (user-error "No LSP client active in this buffer"))))

      (defun my/lsp-start ()
        (interactive)
        (if (derived-mode-p my/eglot-modes)
            (call-interactively #'eglot)
          (call-interactively #'lsp)))

      (defun my/lsp-shutdown ()
        (interactive)
        (my/lsp-dispatch #'eglot-shutdown #'lsp-workspace-shutdown))

      (defun my/lsp-restart ()
        (interactive)
        (my/lsp-dispatch #'eglot-reconnect #'lsp-workspace-restart))

      (defun my/lsp-code-action ()
        (interactive)
        (my/lsp-dispatch #'eglot-code-actions #'lsp-execute-code-action))

      (defun my/lsp-rename ()
        (interactive)
        (my/lsp-dispatch #'eglot-rename #'lsp-rename))

      (defun my/lsp-find-definition ()
        (interactive)
        (my/lsp-dispatch #'xref-find-definitions #'lsp-find-definition))

      (defun my/lsp-find-implementation ()
        (interactive)
        (my/lsp-dispatch #'eglot-find-implementation #'lsp-find-implementation))

      (defun my/lsp-find-type-definition ()
        (interactive)
        (my/lsp-dispatch #'eglot-find-typeDefinition #'lsp-find-type-definition))

      (defun my/lsp-organize-imports ()
        (interactive)
        (my/lsp-dispatch #'eglot-code-action-organize-imports #'lsp-organize-imports))

      (defun my/lsp-inlay-hints ()
        (interactive)
        (my/lsp-dispatch #'eglot-inlay-hints-mode #'lsp-inlay-hints-mode))

      (defun my/lsp-doc-glance ()
        (interactive)
        (my/lsp-dispatch #'eldoc-box-help-at-point #'lsp-ui-doc-glance))

      (evil-leader/set-key
        "lo" 'my/lsp-start
        "lq" 'my/lsp-shutdown
        "la" 'my/lsp-code-action
        "lf" 'apheleia-format-buffer
        "lr" 'my/lsp-rename
        "lR" 'my/lsp-restart
        "lH" 'my/lsp-inlay-hints
        "ld" 'my/lsp-find-definition
        "li" 'my/lsp-find-implementation
        "lt" 'my/lsp-find-type-definition
        "lI" 'my/lsp-organize-imports
        "lh" 'my/lsp-doc-glance
        "ln" 'flymake-goto-next-error
        "lp" 'flymake-goto-prev-error
        "ll" 'consult-flymake)
  '';
}
