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
                               java-ts-mode
                               js-ts-mode
                               python-ts-mode
                               bash-ts-mode
                               yaml-ts-mode
                               typescript-ts-mode
                               tsx-ts-mode
                               rust-ts-mode
                               lua-ts-mode
                               dockerfile-ts-mode))
      :config
      (unless (assoc "\\.mjs\\'" auto-mode-alist)
        (add-to-list 'auto-mode-alist '("\\.mjs\\'" . js-ts-mode))))
  '';
}
