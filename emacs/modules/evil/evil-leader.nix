_:
{
  order = 704;
  elisp = ''
  ;;; Evil Leader
  (use-package evil-leader
    :ensure t
    :config
    (global-evil-leader-mode)
    (evil-leader/set-leader "<SPC>"))
  '';
}
