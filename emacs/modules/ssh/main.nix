_:
{
  order = 1700;
  elisp = ''
    ;;; SSH
    (use-package tramp
      :ensure t
      :config
      (add-to-list 'tramp-remote-path 'tramp-own-remote-path))
  '';
}
