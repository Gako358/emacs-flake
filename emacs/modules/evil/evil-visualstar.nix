_:
{
  order = 707;
  elisp = ''
  ;;; Evil Visual Star
  (use-package evil-visualstar
    :after evil
    :ensure t
    :defer t
    :commands global-evil-visualstar-mode
    :hook (after-init . global-evil-visualstar-mode))
  '';
}
