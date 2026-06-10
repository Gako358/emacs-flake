_:
{
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
        (lsp-metals-bloop-install "off")
        (lsp-metals-default-bsp-to-build-tool t)
        (lsp-metals-fallback-scala-version "3.8.1")
        :config
        (lsp-register-custom-settings
         '(("metals.bloopInstall" "off")
           ("metals.defaultBspToBuildTool" t)
           ("metals.sbtScript" "sbt")))

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
