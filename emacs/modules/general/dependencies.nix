_:
{
  order = 802;
  elisp = ''
  ;;; Dependencies
  (use-package dash :ensure t)
  (use-package s :ensure t)
  (use-package editorconfig
    :ensure t
    :config
    (editorconfig-mode 1))
  (use-package f :ensure t)
  (use-package ansi-color
    :hook (compilation-filter . ansi-color-compilation-filter))
  '';
}
