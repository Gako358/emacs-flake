_:
{
  order = 1905;
  elisp = ''
    ;;; Magit
    (use-package magit
      :ensure t
      :defer t
      :commands magit-status
      :init
      (evil-leader/set-key
        "/" 'magit-status))
  '';
}
