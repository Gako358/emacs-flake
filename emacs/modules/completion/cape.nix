_:
{
  order = 201;
  elisp = ''
    ;;; Cape
  ;; Completion At Point Extensions.
  (use-package cape
    :ensure t
    :after corfu
    :config
    ;; Add completion-at-point backends
    (add-to-list 'completion-at-point-functions
  		 (cape-capf-accept-all #'cape-dabbrev))
    (add-to-list 'completion-at-point-functions
  		 (cape-capf-accept-all #'cape-keyword))
    (add-to-list 'completion-at-point-functions #'cape-history)
    (add-to-list 'completion-at-point-functions #'cape-abbrev)
    (add-to-list 'completion-at-point-functions #'cape-file)
    (add-to-list 'completion-at-point-functions #'cape-elisp-block)

    ;; Set up insert mode specific bindings
    (with-eval-after-load 'evil
      (define-key evil-insert-state-map (kbd "C-c p o") 'completion-at-point)
      (define-key evil-insert-state-map (kbd "C-c p d") 'cape-dabbrev)
      (define-key evil-insert-state-map (kbd "C-c p f") 'cape-file)
      (define-key evil-insert-state-map (kbd "C-c p h") 'cape-history)
      (define-key evil-insert-state-map (kbd "C-c p k") 'cape-keyword)
      (define-key evil-insert-state-map (kbd "C-c p s") 'cape-elisp-symbol)
      (define-key evil-insert-state-map (kbd "C-c p e") 'cape-elisp-block)
      (define-key evil-insert-state-map (kbd "C-c p a") 'cape-abbrev)
      (define-key evil-insert-state-map (kbd "C-c p l") 'cape-line)
      (define-key evil-insert-state-map (kbd "C-c p w") 'cape-dict)
      (define-key evil-insert-state-map (kbd "C-c p :") 'cape-emoji)
      (define-key evil-insert-state-map (kbd "C-c p &") 'cape-sgml)
      (define-key evil-insert-state-map (kbd "C-c p r") 'cape-rfc1345)))
  '';
}
