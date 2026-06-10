_:
{
  order = 1201;
  elisp = ''
    ;;; C
      ;; C language server
      (use-package c-ts-mode
        :mode (("\\.c\\'" . c-ts-mode)
      	   ("\\.h\\'" . c-ts-mode)))
  '';
}
