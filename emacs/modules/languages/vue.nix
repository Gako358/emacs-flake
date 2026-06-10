{ pkgs, ... }:
{
  order = 1216;
  elisp = ''
    ;;; Vue
      ;; Vue
      (use-package vue-ts-mode
        :hook ((vue-ts-mode . (lambda ()
      			    (setq-local lsp-disabled-clients '(vue-semantic-server))
      			    (setq-local lsp-enable-links nil)
      			    (setq-local lsp-lens-enable nil)))
      	 (vue-ts-mode . lsp-deferred))
        :mode ("\\.vue\\'" . vue-ts-mode)
        :config
        (with-eval-after-load 'lsp-mode
          (setq lsp-volar-hybrid-mode t)
          (add-to-list 'lsp-language-id-configuration '(vue-ts-mode . "vue"))

          (advice-add 'lsp-typescript-javascript-tsx-jsx-activate-p
      		  :around
      		  (lambda (orig-fn filename &optional mode)
      		    (or (funcall orig-fn filename mode)
      			(and filename (string-match-p "\\.vue\\'" filename))
      			(derived-mode-p 'vue-ts-mode))))

          (lsp-register-client
           (make-lsp-client
      	:new-connection (lsp-stdio-connection '("vue-language-server" "--stdio"))
      	:activation-fn (lsp-activate-on "vue")
      	:server-id 'volar-remote
      	:priority 10
      	:initialization-options
      	(lambda ()
      	  (list :typescript (list :tsdk (or lsp-typescript-tsdk
      					    (expand-file-name "node_modules/typescript/lib"
      							      (lsp-workspace-root))))
      		:vue (list :hybridMode t)))
      	:notification-handlers (ht ("tsserver/request" #'ignore))
      	:multi-root t))))
      (setq lsp-clients-typescript-plugins
            (vector
             (list :name "@vue/typescript-plugin"
                   :location "${pkgs.vue-language-server}/lib/language-tools/packages/typescript-plugin"
                   :languages (vector "vue"))))
  '';
}
