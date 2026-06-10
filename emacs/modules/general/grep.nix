_:
{
  order = 804;
  elisp = ''
  ;;; Grep
  (use-package wgrep
    :ensure t
    :defer t
    :commands (wgrep-change-to-wgrep-mode wgrep-finish-edit)
    :init
    (with-eval-after-load 'evil-leader
      (evil-leader/set-key
        "we" 'wgrep-change-to-wgrep-mode
        "ws" 'wgrep-finish-edit)))
  '';
}
