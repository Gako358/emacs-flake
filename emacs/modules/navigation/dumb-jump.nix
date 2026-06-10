_: {
  order = 1401;
  elisp = ''
    (use-package dumb-jump
      :ensure t
      :defer t
      :init
      (add-hook 'xref-backend-functions #'dumb-jump-xref-activate)
      (evil-leader/set-key
        "jj" 'xref-find-definitions
        "jb" 'xref-go-back
        "jr" 'xref-find-references
        "jo" 'dumb-jump-go-other-window
        "jq" 'dumb-jump-quick-look)
      :custom
      (dumb-jump-force-searcher 'rg)
      (dumb-jump-prefer-searcher 'rg)
      (dumb-jump-selector 'completing-read))
  '';
}
