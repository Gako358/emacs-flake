_:
{
  order = 103;
  elisp = ''
    ;;; Icons
  (use-package nerd-icons
    :ensure t
    :config
    (setq nerd-icons-font-family "Iosevka Nerd Font"))

  ;; Pretty icons for completion
  (use-package nerd-icons-completion
    :ensure t
    :after marginalia
    :hook (marginalia-mode . nerd-icons-completion-marginalia-setup)
    :config
    (nerd-icons-completion-mode 1))

  (use-package nerd-icons-corfu
    :ensure t
    :after corfu
    :config
    (add-to-list 'corfu-margin-formatters #'nerd-icons-corfu-formatter))
  '';
}
