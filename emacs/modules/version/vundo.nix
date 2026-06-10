_:
{
  order = 1907;
  elisp = ''
    ;;; Vundo
    (use-package vundo
      :ensure t
      :defer t
      :commands vundo
      :custom
      (vundo-glyph-alist vundo-unicode-symbols))
  '';
}
