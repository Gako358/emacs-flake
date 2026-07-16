_:
{
  order = 1209;
  elisp = ''
    ;;; Python
      (use-package python
        :mode ("\\.py\\'" . python-ts-mode))
  '';
}
