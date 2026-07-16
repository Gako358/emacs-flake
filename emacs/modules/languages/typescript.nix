_:
{
  order = 1215;
  elisp = ''
    ;;; TypeScript
      ;; TypeScript language server
      (use-package typescript-ts-mode
        :mode ("\\.ts\\'" . typescript-ts-mode))
  '';
}
