_:
{
  order = 209;
  elisp = ''
    ;;; Vertico
  ;; Vertical interactive completion UI.
  (use-package vertico
    :ensure t
    :defer t
    :commands vertico-mode
    :hook (after-init . vertico-mode))

  (use-package vertico-posframe
    :ensure t
    :after vertico
    :hook (vertico-mode . vertico-posframe-mode)
    :custom
    (vertico-posframe-parameters '((left-fringe . 8) (right-fringe . 8)))
    (vertico-posframe-poshandler #'posframe-poshandler-frame-bottom-right-corner))
  '';
}
