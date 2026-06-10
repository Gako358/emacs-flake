_:
{
  order = 806;
  elisp = ''
  ;;; Proced
  (use-package proced
    :ensure nil
    :defer t
    :custom
    (proced-enable-color-flag t)
    (proced-tree-flag t)
    (proced-filter 'all)
    (proced-sort 'pcpu)
    (proced-format-memory-flag t)
    (proced-format-alist
     '((short user pid tree pcpu pmem start time (args comm))
       (medium user pid tree pcpu pmem vsize rss ttname state start time (args comm))
       (long user euid group pid tree pri nice pcpu pmem vsize rss ttname state start time (args comm))
       (verbose user euid group egid pid ppid tree pgrp sess pri nice pcpu pmem state thcount vsize rss ttname tpgid minflt majflt cminflt cmajflt start time utime stime ctime cutime cstime etime (args comm))
       (performance pid tree pcpu pmem vsize rss state time (args comm))
       (admin user pid ppid tree nice pcpu pmem state start time (args comm))))

    (proced-format 'medium)

    :bind
    ("C-x p p" . proced)

    :config
    (evil-set-initial-state 'proced-mode 'normal)
    (evil-define-key 'normal proced-mode-map
      ;; Navigation
      "j" 'next-line
      "k" 'previous-line
      "gg" 'beginning-of-buffer
      "G" 'end-of-buffer
      "l" 'proced-toggle-tree

      ;; Updates
      "gr" 'proced-update
      "gR" 'proced-revert
      "a" 'proced-toggle-auto-update

      ;; Marking
      "m" 'proced-mark
      "u" 'proced-unmark
      "U" 'proced-unmark-all
      "t" 'proced-toggle-marks

      ;; Actions
      "d" 'proced-send-signal
      "D" (lambda () (interactive) (proced-send-signal 'KILL))
      "x" 'proced-send-signal
      "K" 'proced-send-signal
      "r" 'proced-renice

      ;; Format switching
      "F" 'proced-format-interactive

      ;; Custom functions
      "X" 'my/proced-kill-process-by-name

      ;; Other
      "?" 'describe-mode
      "h" 'describe-mode
      "q" 'quit-window)

    ;; Visual mode for marking multiple processes
    (evil-define-key 'visual proced-mode-map
      "m" 'proced-mark
      "u" 'proced-unmark
      "d" 'proced-send-signal
      "x" 'proced-send-signal)

    ;; Face customization
    (set-face-attribute 'proced-mark nil
                        :background "#3c3836"
                        :foreground "#fb4934"
                        :weight 'bold)

    (defun my/proced-highlight-high-usage ()
      "Highlight processes with high CPU or memory usage."
      (save-excursion
        (goto-char (point-min))
        (while (not (eobp))
          (let ((line (thing-at-point 'line t)))
            (when line
              (when (string-match "\\s-\\([5-9][0-9]\\|100\\)\\.[0-9]\\s-" line)
                (put-text-property (line-beginning-position) (line-end-position)
                                   'face '(:foreground "#fb4934")))
              (when (string-match "\\s-\\(2[0-9]\\|[3-9][0-9]\\|100\\)\\.[0-9]\\s-" line)
                (unless (get-text-property (line-beginning-position) 'face)
                  (put-text-property (line-beginning-position) (line-end-position)
                                     'face '(:foreground "#fabd2f"))))))
          (forward-line 1))))

    (add-hook 'proced-post-display-hook #'my/proced-highlight-high-usage)

    (defun my/proced-kill-process-by-name (name)
      "Kill all processes matching NAME."
      (interactive "sProcess name: ")
      (proced)
      (proced-filter-interactive 'all)
      (goto-char (point-min))
      (let ((count 0))
        (while (search-forward name nil t)
          (when (save-excursion
                  (beginning-of-line)
                  (looking-at "^\\s-*\\S-+\\s-+\\([0-9]+\\)"))
            (proced-mark)
            (setq count (1+ count))))
        (when (> count 0)
          (proced-send-signal 'TERM)
          (message "Sent TERM signal to %d process(es)" count))))

    (defun my/proced-show-active ()
      "Show only processes that are actively using CPU or have high memory usage."
      (interactive)
      (proced-filter-interactive
       (lambda (proc)
         (let ((pcpu (cdr (assq 'pcpu (process-attributes proc))))
               (pmem (cdr (assq 'pmem (process-attributes proc)))))
           (or (and pcpu (> pcpu 1.0))
               (and pmem (> pmem 5.0)))))))

    (easy-menu-define proced-custom-menu proced-mode-map
      "Custom menu for Proced mode"
      '("Proced"
        ["Show Active Processes" my/proced-show-active t]
        ["Kill by Name" my/proced-kill-process-by-name t]
        "---"
        ["Toggle Tree View" proced-toggle-tree t]
        ["Toggle Auto Update" proced-toggle-auto-update t])))
  '';
}
