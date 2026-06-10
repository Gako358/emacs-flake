_:
{
  order = 206;
  elisp = ''
    ;;; Eldoc
  (use-package eldoc-box
    :ensure t
    :config
    (evil-leader/set-key
      "lh" 'eldoc-box-help-at-point))
  '';
}
