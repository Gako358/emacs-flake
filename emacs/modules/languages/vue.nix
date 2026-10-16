{ pkgs, ... }:
{
  order = 1216;
  elisp = ''
    ;;; Vue
      (use-package vue-ts-mode
        :mode ("\\.vue\\'" . vue-ts-mode)
        :hook (vue-ts-mode . (lambda ()
                               (setq-local lsp-enable-links nil)
                               (setq-local lsp-lens-enable nil)))
        :config
        ;; tree-sitter-vue renamed directive_argument to directive_value, so the
        ;; upstream vue-directive rule fails to compile and is disabled with a
        ;; treesit-font-lock-rules-mismatch warning.
        (let ((fixed (car (treesit-font-lock-rules
                           :language 'vue
                           :override t
                           :feature 'vue-directive
                           '((_ (_ (directive_attribute
                                    (directive_name) @font-lock-keyword-face
                                    (directive_value) @font-lock-type-face))))))))
          (setq vue-font-lock-settings
                (mapcar (lambda (s)
                          (if (eq (treesit-font-lock-setting-feature s) 'vue-directive)
                              fixed
                            s))
                        vue-font-lock-settings))))
      ;; lsp-volar's plugin auto-detection resolves the nix binary wrapper to the
      ;; store root, where tsserver cannot find @vue/typescript-plugin; point it
      ;; at the package whose node_modules contains the plugin.
      (setq lsp-volar-location-for-typescript-plugin
            "${pkgs.vue-language-server}/lib/language-tools/packages/language-server")
  '';
}
