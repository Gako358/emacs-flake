_:
{
  order = 1401;
  elisp = ''
    ;;; Dumb Jump
  (use-package dumb-jump
    :ensure t
    :init
    ;; Add as a fallback xref backend (LSP/elisp/etc. take priority).
    (add-hook 'xref-backend-functions #'dumb-jump-xref-activate)
    :custom
    (dumb-jump-force-searcher 'rg)
    (dumb-jump-prefer-searcher 'rg)
    (dumb-jump-selector 'completing-read)
    :config
    (evil-leader/set-key
      "jj" 'xref-find-definitions
      "jb" 'xref-go-back
      "jr" 'xref-find-references
      "jo" 'dumb-jump-go-other-window
      "jq" 'dumb-jump-quick-look))
  '';
}
