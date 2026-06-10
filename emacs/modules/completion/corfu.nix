_:
{
  order = 202;
  elisp = ''
    ;;; Corfu
  ;; Completion Overlay Region Function.
  (use-package corfu
    :defer 0.1
    :init
    (global-corfu-mode 1)
    (setq global-corfu-minibuffer
  	(lambda ()
  	  (not (or (bound-and-true-p mct--active)
  		   (bound-and-true-p vertico--input)
  		   (eq (current-local-map) read-passwd-map)))))
    :bind (:map corfu-map
  	      ("C-n" . corfu-next)
  	      ("C-p" . corfu-previous)
  	      ("C-h" . corfu-info-documentation)
  	      ("C-S-t" . my/corfu-quit-or-abort))

    :custom
    (corfu-cycle t)
    (corfu-auto t)
    (corfu-preview-current nil)
    (corfu-quit-at-boundary t)
    (corfu-quit-no-match t)

    :config
    ;; Add Evil-specific binding for C-y in Corfu
    (with-eval-after-load 'evil
      (define-key evil-insert-state-map (kbd "C-y")
                  (lambda ()
                    (interactive)
                    (if (and (boundp 'corfu-mode) corfu-mode)
                        (corfu-insert)
                      (evil-paste-before 1)))))

    ;; Remove ispell word-list completion (no plain word-list on NixOS)
    (setq completion-at-point-functions
          (remove 'ispell-completion-at-point completion-at-point-functions))

    (defun my/remove-ispell-capf ()
      "Remove ispell-completion-at-point from buffer-local capfs."
      (setq-local completion-at-point-functions
                  (remove 'ispell-completion-at-point completion-at-point-functions)))
    (add-hook 'text-mode-hook #'my/remove-ispell-capf)
    (add-hook 'git-commit-mode-hook #'my/remove-ispell-capf)

    (defun my/corfu-quit-or-abort ()
      "Abort Corfu if active, otherwise fall back to default behavior."
      (interactive)
      (if corfu--frame
          (corfu-quit)
        (keyboard-escape-quit))))
  '';
}
