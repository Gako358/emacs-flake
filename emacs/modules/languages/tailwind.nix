_:
{
  order = 1214;
  elisp = ''
    ;;; Tailwind CSS
      ;; Upstream lsp-tailwindcss is deprecated and now ships as a client
      ;; bundled inside lsp-mode, so it is no longer a standalone package.
      (use-package lsp-tailwindcss
        :ensure nil
        :after lsp-mode
        :init
        ;; Must be set in :init, before the package loads.
        (setq lsp-tailwindcss-add-on-mode t)
        :custom
        ;; Default list uses non-ts modes; extend it for our tree-sitter modes.
        (lsp-tailwindcss-major-modes
         '(vue-ts-mode
           typescript-ts-mode
           tsx-ts-mode
           web-mode
           html-mode
           css-mode
           css-ts-mode)))
  '';
}
