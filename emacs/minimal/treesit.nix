_:
{
  order = 902;
  elisp = ''
    ;;; Tree-sitter (minimal: built-in ts-modes + nix)
    (use-package treesit
      :ensure nil
      :custom
      (treesit-font-lock-level 4)
      :config
      ;; Redirect classic built-in modes to their tree-sitter counterparts.
      (dolist (m '((c-mode . c-ts-mode)
                   (css-mode . css-ts-mode)
                   (java-mode . java-ts-mode)
                   (js-mode . js-ts-mode)
                   (javascript-mode . js-ts-mode)
                   (python-mode . python-ts-mode)
                   (sh-mode . bash-ts-mode)))
        (add-to-list 'major-mode-remap-alist m))
      ;; Languages whose classic major mode isn't bundled in the minimal set:
      ;; bind the file extension straight to the built-in tree-sitter mode.
      (dolist (a '(("\\.ya?ml\\'" . yaml-ts-mode)
                   ("\\.ts\\'" . typescript-ts-mode)
                   ("\\.tsx\\'" . tsx-ts-mode)
                   ("\\.rs\\'" . rust-ts-mode)
                   ("\\.lua\\'" . lua-ts-mode)
                   ("Dockerfile\\'" . dockerfile-ts-mode)))
        (add-to-list 'auto-mode-alist a)))
  '';
}
