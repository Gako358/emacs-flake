_:
{
  order = 1209;
  elisp = ''
    ;;; Python
      (use-package python
        :mode ("\\.py\\'" . python-ts-mode)
        :config
        (setq lsp-disabled-clients '(semgrep-ls ruff pyls ty-ls basedpyright pyright))
        (with-eval-after-load 'lsp-mode
          (lsp-register-client
           (make-lsp-client
      	:new-connection (lsp-stdio-connection "pylsp")
      	:major-modes '(python-ts-mode python-mode)
      	:server-id 'pylsp
      	:priority 10))))
  '';
}
