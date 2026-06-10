_:
{
  order = 106;
  elisp = ''
    ;;; Indent Bars
  (use-package indent-bars
    :ensure t
    :hook ((prog-mode yaml-mode yaml-ts-mode) . indent-bars-mode)
    :custom
    ;; Tree-sitter integration — leverage the grammars already loaded.
    (indent-bars-treesit-support t)
    (indent-bars-treesit-ignore-blank-lines-types '("module"))
    ;; Subtle, theme-aware appearance
    (indent-bars-color '(highlight :face-bg t :blend 0.15))
    (indent-bars-pattern ".")
    (indent-bars-width-frac 0.1)
    (indent-bars-pad-frac 0.1)
    (indent-bars-zigzag nil)
    (indent-bars-color-by-depth nil)
    (indent-bars-highlight-current-depth '(:blend 0.5))
    (indent-bars-display-on-blank-lines nil))
  '';
}
