_:
{
  order = 105;
  elisp = ''
    ;;; Themes
  (use-package bivrost-theme
    :ensure t
    :config
    (load-theme 'bivrost t))
  '';
}
