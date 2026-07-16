{ pkgs, ... }:
{
  order = 1215;
  elisp = ''
    ;;; TypeScript
      ;; TypeScript language server
      (use-package typescript-ts-mode
        :mode ("\\.ts\\'" . typescript-ts-mode))
      (setq lsp-typescript-tsdk "${pkgs.typescript}/lib/node_modules/typescript/lib")
  '';
}
