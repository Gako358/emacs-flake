_:
{
  order = 1204;
  elisp = ''
    ;;; Java
      ;; Java language server
      (use-package lsp-java
        :ensure t
        :hook (java-ts-mode . (lambda ()
      			    (require 'lsp-java)))
        :config
        (evil-leader/set-key
          "ljn" 'lsp-java-add-import
          "ljx" 'lsp-java-spring-run
          "ljt" 'lsp-java-run-test
          "ljg" 'lsp-java-generate-getters-and-setters
          "ljs" 'lsp-java-generate-to-string
          "ljo" 'lsp-java-generate-overrides
          "ljb" 'lsp-java-build-project
          "ljc" 'lsp-java-create-parameter
          "lje" 'lsp-java-extract-to-constant
          "ljm" 'lsp-java-extract-method
          "ljI" 'lsp-java-organize-imports))

      ;; Java debug helpers (dap-java is required from the DAP block).
      ;; Loaded lazily so the symbols exist when the leader is pressed.
      (with-eval-after-load 'dap-java
        (evil-leader/set-key
          "ljd" 'dap-java-debug                  ; debug current main class
          "ljD" 'dap-java-debug-test-class       ; debug all tests in class
          "ljM" 'dap-java-debug-test-method))    ; debug test method at point
  '';
}
