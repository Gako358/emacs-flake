_: {
  order = 1211;
  elisp = ''
    ;;; Scala
      ;; Scala language server
      (use-package scala-ts-mode
        :mode "\\.scala\\'"
        :hook (scala-ts-mode . (lambda ()
      			     (require 'lsp-metals))))

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
