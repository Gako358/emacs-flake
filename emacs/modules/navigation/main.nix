_:
{
  order = 1400;
  elisp = ''
    ;;; Navigation
  ;; Consulting completing-read
  (use-package consult
    :ensure t
    :custom
    (consult-preview-key (list :debounce 0.1 'any))
    :config

    (defun my/consult-replace-word-with-preview ()
      "Replace occurrences of word under cursor using `consult-ripgrep' for preview.
  If a region is active, use the selected text instead."
      (interactive)
      (let* ((bounds (if (evil-visual-state-p)
                         (cons (region-beginning) (region-end))
                       (bounds-of-thing-at-point 'word)))
             (word (when bounds
                     (buffer-substring-no-properties (car bounds) (cdr bounds)))))
        (when word
          (when (evil-visual-state-p) (evil-normal-state))
          (consult-ripgrep nil (regexp-quote word))
          (let ((new-word (read-string (format "Replace \"%s\" with: " word))))
            (when new-word
              (evil-ex (format "%%s/%s/%s/gc"
                               (regexp-quote word)
                               new-word)))))))

    (defun my/consult-replace-word-in-buffer ()
      "Replace word under cursor in the current buffer using `consult-line' preview."
      (interactive)
      (let* ((bounds (if (evil-visual-state-p)
                         (cons (region-beginning) (region-end))
                       (bounds-of-thing-at-point 'word)))
             (word (when bounds
                     (buffer-substring-no-properties (car bounds) (cdr bounds)))))
        (when word
          (when (evil-visual-state-p) (evil-normal-state))
          (consult-line (regexp-quote word))
          (let ((new-word (read-string (format "Replace \"%s\" with: " word))))
            (when new-word
              (evil-ex (format "%%s/%s/%s/gc"
                               (regexp-quote word)
                               new-word)))))))

    (evil-leader/set-key
      "ff" 'consult-find
      "fg" 'consult-ripgrep
      "sb" 'my/consult-replace-word-with-preview
      "sr" 'my/consult-replace-word-in-buffer))

  (use-package consult-lsp
    :ensure t
    :after (consult lsp-mode)
    :config
    (evil-leader/set-key
      "lw" 'consult-lsp-diagnostics))

  (use-package consult-projectile
    :ensure t
    :after (consult projectile)
    :config
    (defun my/consult-projectile-grep-at-point ()
      "Grep within the current project for the word/symbol at point.
  If a region is active, use the selected text instead. Symbols
  containing =-= or =_= are matched as a whole symbol rather than just
  the word under point."
      (interactive)
      (let ((search-term
             (if (use-region-p)
                 (buffer-substring-no-properties (region-beginning) (region-end))
               (let* ((word (thing-at-point 'word t))
                      (bounds (bounds-of-thing-at-point 'symbol))
                      (symbol (when bounds
                                (buffer-substring-no-properties
                                 (car bounds) (cdr bounds)))))
                 (if (and word (or (string-match-p "-" word)
                                   (string-match-p "_" word)))
                     symbol
                   word)))))
        (consult-ripgrep (projectile-project-root) search-term)))

    (defun my/switch-to-previous-buffer ()
      "Switch to the most recently visited buffer in the current Projectile project.
  Falls back to `consult-projectile-switch-to-buffer' when no other
  project buffer is available."
      (interactive)
      (let* ((current-project (projectile-project-root))
             (project-buffers
              (seq-filter
               (lambda (buf)
                 (with-current-buffer buf
                   (when (buffer-file-name)
                     (and current-project
                          (string= (projectile-project-root (buffer-file-name))
                                   current-project)))))
               (buffer-list))))
        (if (and project-buffers (> (length project-buffers) 1))
            ;; nth 1 = the buffer just under the current one in MRU order.
            (switch-to-buffer (nth 1 project-buffers))
          (message "No previous buffer in the current project; using consult-projectile-switch-to-buffer.")
          (call-interactively #'consult-projectile-switch-to-buffer))))

    (evil-leader/set-key
      "SPC" 'my/consult-projectile-grep-at-point
      "pf"  'consult-projectile-find-file
      "pw"  'consult-projectile-find-file-other-window
      "pp"  'consult-projectile-switch-project
      "pb"  'consult-buffer
      "TAB"  'consult-projectile-switch-to-buffer)

    (global-set-key (kbd "<C-tab>") #'my/switch-to-previous-buffer))
  '';
}
