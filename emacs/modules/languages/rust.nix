_:
{
  order = 1210;
  elisp = ''
    ;;; Rust
      ;; Rust language server
      (use-package rust-ts-mode
        :mode "\\.rs\\'"
        :init
        (with-eval-after-load 'org
          (cl-pushnew '("rust" . rust-ts-mode) org-src-lang-modes :test #'equal)))
  '';
}
