_:
{
  order = 400;
  elisp = ''
  ;;; Document
  (use-package pdf-tools
    :ensure t
    :defer t
    :hook (pdf-view-mode . (lambda ()
  			     (display-line-numbers-mode -1)))
    :config
    (pdf-tools-install)
    (setq-default pdf-view-display-size 'fit-page))
  '';
}
