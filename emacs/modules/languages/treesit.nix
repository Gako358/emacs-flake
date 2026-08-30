_:
{
  order = 902;
  elisp = ''
    (use-package treesit
      :ensure nil
      :custom
      (treesit-font-lock-level 4)
      (treesit-enabled-modes '(c-ts-mode
                               css-ts-mode
                               dockerfile-ts-mode
                               java-ts-mode
                               js-ts-mode
                               lua-ts-mode
                               python-ts-mode
                               bash-ts-mode
                               typescript-ts-mode
                               yaml-ts-mode))
      :config
      (unless (assoc "\\.mjs\\'" auto-mode-alist)
        (add-to-list 'auto-mode-alist '("\\.mjs\\'" . js-ts-mode)))
      (dolist (m '((haskell-mode . haskell-ts-mode)
                   (kotlin-mode . kotlin-ts-mode)
                   (scala-mode . scala-ts-mode)))
        (add-to-list 'major-mode-remap-alist m)))
  '';
}
