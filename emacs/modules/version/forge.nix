_:
{
  order = 1903;
  elisp = ''
    ;;; Forge
    (use-package forge
      :after magit
      :init
      (setq forge-add-default-bindings nil)
      :config
      (setq auth-sources '("~/.authinfo")))
  '';
}
