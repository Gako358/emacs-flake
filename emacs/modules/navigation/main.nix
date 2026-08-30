_:
{
  order = 1400;
  elisp = ''
    ;;; Navigation
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
                (query-replace word new-word nil (point-min) (point-max)))))))

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
                (query-replace word new-word nil (point-min) (point-max)))))))

      (defun my/project-grep-at-point ()
        "Grep within the current project for the word or symbol at point."
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
          (consult-ripgrep (when-let* ((project (project-current)))
                             (project-root project))
                            search-term)))

      (defun my/switch-to-previous-buffer ()
        "Switch to the most recently visited file-backed buffer in this project."
        (interactive)
        (let* ((current (current-buffer))
               (current-file (buffer-file-name current))
               (current-directory default-directory))
          (if (or (and current-file (file-remote-p current-file))
                  (and current-directory (file-remote-p current-directory)))
              (call-interactively #'project-switch-to-buffer)
            (if-let* ((current-project (project-current nil))
                      (previous
                       (seq-find
                        (lambda (candidate)
                          (and (not (eq candidate current))
                               (let ((candidate-file
                                      (buffer-file-name candidate)))
                                 (and candidate-file
                                      (not (file-remote-p candidate-file))
                                      (let ((candidate-directory
                                             (file-name-directory candidate-file)))
                                        (and candidate-directory
                                             (equal current-project
                                                    (project-current
                                                     nil candidate-directory))))))))
                        (buffer-list))))
                (switch-to-buffer previous)
              (call-interactively #'project-switch-to-buffer)))))

      (evil-leader/set-key
        "ff" #'consult-find
        "fg" #'consult-ripgrep
        "sb" #'my/consult-replace-word-with-preview
        "sr" #'my/consult-replace-word-in-buffer
        "SPC" #'my/project-grep-at-point
        "pf" #'project-find-file
        "pw" #'merrinx/project-find-file-other-window
        "pp" #'project-switch-project
        "pb" #'consult-buffer
        "TAB" #'project-switch-to-buffer)

      (global-set-key (kbd "<C-tab>") #'my/switch-to-previous-buffer))

    (use-package consult-lsp
      :ensure t
      :after (consult lsp-mode)
      :config
      (evil-leader/set-key
        "lw" 'consult-lsp-diagnostics))
  '';
}
