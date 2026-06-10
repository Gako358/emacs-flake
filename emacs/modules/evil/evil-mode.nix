_:
{
  order = 701;
  elisp = ''
  ;;; Evil Mode
  ;; NOTE: `evil-want-integration' and `evil-want-keybinding' are set in the
  ;; "Early Init" section at the very top of this file, before any package
  ;; can transitively load evil.
  (use-package evil
    :ensure t
    :custom
    (evil-want-Y-yank-to-eol t)
    :config
    (evil-select-search-module 'evil-search-module 'evil-search)
    (evil-mode 1))

  ;; Define scroll up
  (define-key evil-normal-state-map (kbd "C-u") 'evil-scroll-up)
  (define-key evil-visual-state-map (kbd "C-u") 'evil-scroll-up)
  ;; (define-key evil-insert-state-map (kbd "C-u")
  ;;       	    (lambda ()
  ;;       	      (interactive)
  ;;       	      (evil-delete (point-at-bol) (point))))

  ;; Evil numbers inc and dec
  (define-key evil-normal-state-map (kbd "C-a") 'evil-numbers/inc-at-pt)
  (define-key evil-visual-state-map (kbd "C-a") 'evil-numbers/inc-at-pt)
  (define-key evil-normal-state-map (kbd "C-i") 'evil-numbers/dec-at-pt)
  (define-key evil-visual-state-map (kbd "C-i") 'evil-numbers/dec-at-pt)
  ;; Redefine keys for switching windows
  (define-key evil-normal-state-map (kbd "C-l") 'evil-window-right)
  (define-key evil-normal-state-map (kbd "C-h") 'evil-window-left)
  (define-key evil-normal-state-map (kbd "C-j") 'evil-window-down)
  (define-key evil-normal-state-map (kbd "C-k") 'evil-window-up)
  '';
}
