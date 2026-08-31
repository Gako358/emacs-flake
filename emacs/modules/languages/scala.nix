_: {
  order = 1211;
  elisp = ''
    ;;; Scala
      ;; Scala language server
      (use-package scala-ts-mode
        :mode "\\.scala\\'"
        :hook (scala-ts-mode . (lambda ()
      			     (require 'lsp-metals)))
        :config
        ;; "macro" is not a grammar terminal in tree-sitter-scala and "end" is
        ;; scanner-lexed (accessible only as end_marker). Emacs 31 validates
        ;; treesit queries strictly; both tokens cause the keyword feature to be
        ;; silently disabled. Replace it with a corrected version.
        (let* ((kws (seq-filter (lambda (k) (not (member k '("macro" "end"))))
                                scala-ts--keywords))
               (fixed
                (treesit-font-lock-rules
                 :language 'scala
                 :feature 'keyword
                 `([,@kws] @font-lock-keyword-face
                   [,@scala-ts--keywords-type-qualifiers] @font-lock-keyword-face
                   (end_marker) @font-lock-keyword-face
                   (opaque_modifier) @font-lock-keyword-face
                   (infix_modifier) @font-lock-keyword-face
                   (transparent_modifier) @font-lock-keyword-face
                   (open_modifier) @font-lock-keyword-face
                   (inline_modifier) @font-lock-keyword-face
                   (infix_modifier) @font-lock-keyword-face
                   [,@scala-ts--keywords-control] @font-lock-keyword-face
                   (null_literal) @font-lock-builtin-face
                   (wildcard) @font-lock-builtin-face
                   (annotation) @font-lock-preprocessor-face
                   (indented_cases
                    (case_clause ("case") @font-lock-keyword-face))
                   (case_block
                    (case_clause ("case") @font-lock-keyword-face))))))
          (setq scala-ts--treesit-font-lock-settings
                (append fixed
                        (seq-remove
                         (lambda (s)
                           (eq (treesit-font-lock-setting-feature s) 'keyword))
                         scala-ts--treesit-font-lock-settings)))))

      (use-package lsp-metals
        :ensure t
        :after (scala-ts-mode lsp-mode)
        :custom
        (lsp-metals-server-command "metals")
        (lsp-metals-sbt-script "sbt")
        (lsp-metals-fallback-scala-version "3.8.1")
        :config
        (lsp-register-custom-settings
         '(("metals.defaultBspToBuildTool" t)))

        ;; Notifications introduced by Metals 2.0 that lsp-metals does not
        ;; know about yet; without a handler every one of them raises a
        ;; warning and, for the terminal ones, a stream of them.
        (let ((handlers (lsp--client-notification-handlers
                         (gethash 'metals lsp-clients))))
          (dolist (method '("metals/syncStatus"
                            "metals/syncModes"
                            "metals/createTerminal"
                            "metals/endTerminal"
                            "metals/terminalOutput"))
            (puthash method #'ignore handlers)))

        (evil-leader/set-key
          "lsb" 'lsp-metals-build-import
          "lsc" 'lsp-metals-build-connect
          "lss" 'lsp-metals-sources-scan
          "lsd" 'lsp-metals-doctor-run
          "lsn" 'lsp-metals-new-scala-file
          "lsN" 'lsp-metals-new-scala-project
          "lst" 'lsp-metals-treeview))
  '';
}
