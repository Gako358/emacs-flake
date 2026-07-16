{ pkgs, ... }:
{
  order = 1216;
  elisp = ''
    ;;; Vue
      (use-package vue-ts-mode
        :mode ("\\.vue\\'" . vue-ts-mode)
        :hook (vue-ts-mode . (lambda ()
                               (setq-local lsp-enable-links nil)
                               (setq-local lsp-lens-enable nil))))
      ;; lsp-volar's plugin auto-detection resolves the nix binary wrapper to the
      ;; store root, where tsserver cannot find @vue/typescript-plugin; point it
      ;; at the package whose node_modules contains the plugin.
      (setq lsp-volar-location-for-typescript-plugin
            "${pkgs.vue-language-server}/lib/language-tools/packages/language-server")
  '';
}
