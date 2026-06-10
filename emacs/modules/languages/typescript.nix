{ pkgs, ... }:
{
  order = 1215;
  elisp = ''
    ;;; TypeScript
      ;; TypeScript language server
      (use-package typescript-ts-mode
        :mode ("\\.ts\\'" . typescript-ts-mode)
        :hook (typescript-ts-mode . lsp-deferred))
      (setq lsp-typescript-tsdk "${pkgs.typescript}/lib/node_modules/typescript/lib")
  '';
}
