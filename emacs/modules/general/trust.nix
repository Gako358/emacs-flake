_:
{
  order = 807;
  elisp = ''
    ;;; Trust management (Emacs 30 trusted-content)
    (use-package trust-manager
      :ensure t
      :defer 1
      :config
      (trust-manager-mode 1))
  '';
}
