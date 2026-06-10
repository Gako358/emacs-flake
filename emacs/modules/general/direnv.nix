_:
{
  order = 803;
  elisp = ''
  ;;; direnv
  ;;; Direnv integration (asynchronous fork of envrc)
  (use-package ben
    :ensure t
    :bind
    (:map ben-mode-map
          ("C-c e" . ben-command-map))
    :config
    (with-eval-after-load 'nerd-icons
      (let ((icon (nerd-icons-faicon "nf-fa-cubes")))
        (setq ben-none-indicator
              `(,icon " " (:propertize "none"
                                       face ben-mode-line-none-face
                                       mouse-face mode-line-highlight))
              ben-on-indicator
              `(,icon " " (:propertize "on"
                                       face ben-mode-line-on-face
                                       mouse-face mode-line-highlight))
              ben-denied-indicator
              `(,icon " " (:propertize "denied"
                                       face ben-mode-line-denied-face
                                       mouse-face mode-line-highlight))
              ben-error-indicator
              `(,icon " " (:propertize "error"
                                       face ben-mode-line-error-face
                                       mouse-face mode-line-highlight)))
        (setq ben-indicator '(" " (:eval (ben--status))))))
    :hook (after-init . ben-global-mode))
  '';
}
