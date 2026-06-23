_:
{
  order = 1802;
  elisp = ''
    ;;; Ghostel
    (use-package ghostel
      :ensure t
      :commands (ghostel
                 ghostel-project
                 ghostel-other
                 ghostel-next
                 ghostel-previous
                 ghostel-project-next
                 ghostel-project-previous
                 ghostel-list-buffers
                 ghostel-project-list-buffers
                 ghostel-send-C-c)
      :custom
      (ghostel-kill-buffer-on-exit t)
      (ghostel-project-buffer-scope 'both)
      ;; The native module is provided by Nix; never try to download or
      ;; compile it at runtime.
      (ghostel-module-auto-install nil)
      ;; ghostel-color-* inherit from `ansi-color-*', which bivrost-theme
      ;; doesn't style; redirect them at the theme's eat palette so the
      ;; terminal uses the real colours and tracks future theme changes.
      :custom-face
      (ghostel-color-black        ((t (:inherit eat-term-color-0))))
      (ghostel-color-red          ((t (:inherit eat-term-color-1))))
      (ghostel-color-green        ((t (:inherit eat-term-color-2))))
      (ghostel-color-yellow       ((t (:inherit eat-term-color-3))))
      (ghostel-color-blue         ((t (:inherit eat-term-color-4))))
      (ghostel-color-magenta      ((t (:inherit eat-term-color-5))))
      (ghostel-color-cyan         ((t (:inherit eat-term-color-6))))
      (ghostel-color-white        ((t (:inherit eat-term-color-7))))
      (ghostel-color-bright-black   ((t (:inherit eat-term-color-8))))
      (ghostel-color-bright-red     ((t (:inherit eat-term-color-9))))
      (ghostel-color-bright-green   ((t (:inherit eat-term-color-10))))
      (ghostel-color-bright-yellow  ((t (:inherit eat-term-color-11))))
      (ghostel-color-bright-blue    ((t (:inherit eat-term-color-12))))
      (ghostel-color-bright-magenta ((t (:inherit eat-term-color-13))))
      (ghostel-color-bright-cyan    ((t (:inherit eat-term-color-14))))
      (ghostel-color-bright-white   ((t (:inherit eat-term-color-15)))))

    ;; evil-collection covers vterm but not ghostel; evil-ghostel is the
    ;; upstream counterpart.
    (use-package evil-ghostel
      :ensure t
      :after (ghostel evil)
      :hook (ghostel-mode . evil-ghostel-mode))

    ;; Route every `compilation-start' caller (`compile', `recompile',
    ;; `project-compile' / `C-x p c', ...) through a real PTY so colours,
    ;; progress bars and TUI tools render. The finished buffer derives from
    ;; `compilation-mode', so error regexps and `next-error' still work.
    ;; ghostel-compile ships inside the ghostel package (not a separate ELPA
    ;; package), and `ghostel-compile-global-mode' is autoloaded — so no
    ;; `:ensure'/`:after' (the latter would defer the hook past `after-init'
    ;; because `ghostel' itself is lazy-loaded).
    (use-package ghostel-compile
      :ensure nil
      :hook (after-init . ghostel-compile-global-mode))

    (defun my/ghostel-other-window ()
      "Open a Ghostel terminal in another window."
      (interactive)
      (let ((display-buffer-overriding-action
             '((display-buffer-pop-up-window)
               (inhibit-same-window . t))))
        (ghostel)))

    (defvar my/ghostel-toggle--window-config nil
      "Window configuration saved before popping up the ghostel terminal.")

    (defun my/ghostel-toggle ()
      "Toggle a project-scoped Ghostel terminal.
    From a ghostel buffer, restore the previous window layout (or bury the
    buffer).  Otherwise pop up the current project's terminal, creating it
    if necessary."
      (interactive)
      (if (derived-mode-p 'ghostel-mode)
          (if (window-configuration-p my/ghostel-toggle--window-config)
              (progn
                (set-window-configuration my/ghostel-toggle--window-config)
                (setq my/ghostel-toggle--window-config nil))
            (if (one-window-p)
                (bury-buffer)
              (delete-window)))
        (setq my/ghostel-toggle--window-config (current-window-configuration))
        (if (project-current)
            (ghostel-project)
          (ghostel))))

    (defun my/ghostel-toggle-cd ()
      "Show the project's Ghostel terminal and `cd' into the current directory."
      (interactive)
      (let ((dir default-directory))
        (my/ghostel-toggle)
        (when (derived-mode-p 'ghostel-mode)
          (ghostel-send-string (concat "cd " (shell-quote-argument dir)))
          (ghostel-send-key "return"))))

    (evil-leader/set-key
      "tt" 'my/ghostel-toggle
      "tn" 'ghostel-project
      "td" 'ghostel
      "to" 'my/ghostel-other-window
      "tl" 'ghostel-project-list-buffers
      "tk" 'ghostel-send-C-c)

    (evil-leader/set-key
      "tc" 'my/ghostel-toggle-cd
      "tf" 'ghostel-next
      "tb" 'ghostel-previous)

    ;; --- Project-scoped toggleable ghostel posframe ---
    (use-package posframe :ensure t)

    (defvar my/ghostel-posframe-buffers (make-hash-table :test 'equal)
      "Hash table mapping project root paths to their ghostel buffer names.")

    (defvar my/ghostel-posframe-visible (make-hash-table :test 'equal)
      "Hash table tracking whether the posframe is currently visible for a project.")

    (defvar my/ghostel-posframe--saved-window-config nil
      "Saved window configuration before showing the posframe.")

    (defcustom my/ghostel-posframe-width-ratio 0.8
      "Width of the floating ghostel terminal as a ratio of the frame width."
      :type 'float)

    (defcustom my/ghostel-posframe-height-ratio 0.6
      "Height of the floating ghostel terminal as a ratio of the frame height."
      :type 'float)

    (defun my/ghostel-posframe--project-root ()
      "Return the current project root, falling back to `default-directory'."
      (or (projectile-project-root) default-directory))

    (defun my/ghostel-posframe--buffer-name (project-root)
      "Return the ghostel buffer name for PROJECT-ROOT."
      (format "*ghostel-posframe[%s]*" (abbreviate-file-name project-root)))

    (defun my/ghostel-posframe--get-or-create-buffer (project-root)
      "Get or create a ghostel buffer for PROJECT-ROOT."
      (let* ((buf-name (my/ghostel-posframe--buffer-name project-root))
             (existing (gethash project-root my/ghostel-posframe-buffers)))
        (when (and existing (not (buffer-live-p (get-buffer existing))))
          (remhash project-root my/ghostel-posframe-buffers)
          (remhash project-root my/ghostel-posframe-visible)
          (setq existing nil))
        (if existing
            existing
          (let ((default-directory project-root)
                ;; Keep the buffer name stable: ghostel otherwise renames
                ;; buffers from the terminal title, which would break the
                ;; name-based bookkeeping below.
                (ghostel-buffer-name buf-name)
                (ghostel-buffer-name-function nil))
            (let ((buf (save-window-excursion (ghostel))))
              (puthash project-root (buffer-name buf) my/ghostel-posframe-buffers)
              (puthash project-root nil my/ghostel-posframe-visible)
              (buffer-name buf))))))

    (defun my/ghostel-posframe--undedicate-windows (buf)
      "Remove window dedication from all windows showing BUF."
      (dolist (win (get-buffer-window-list buf t t))
        (set-window-dedicated-p win nil)))

    (defun my/ghostel-posframe--show (project-root)
      "Show the ghostel posframe for PROJECT-ROOT."
      (let* ((buf-name (my/ghostel-posframe--get-or-create-buffer project-root))
             (buf (get-buffer buf-name))
             (width (round (* (frame-width) my/ghostel-posframe-width-ratio)))
             (height (round (* (frame-height) my/ghostel-posframe-height-ratio)))
             (parent (selected-frame)))
        (setq my/ghostel-posframe--saved-window-config (current-window-configuration))
        (my/ghostel-posframe--undedicate-windows buf)
        (posframe-show buf-name
                       :poshandler #'posframe-poshandler-frame-center
                       :width width
                       :height height
                       :min-width width
                       :min-height height
                       :border-width 2
                       :border-color "#51afef"
                       :accept-focus t)
        (when-let* ((child (buffer-local-value 'posframe--frame buf)))
          (when (frame-live-p child)
            (x-focus-frame child)
            (my/ghostel-posframe--undedicate-windows buf)))
        (puthash project-root parent my/ghostel-posframe-visible)))

    (defun my/ghostel-posframe--hide (project-root)
      "Hide the ghostel posframe for PROJECT-ROOT."
      (let* ((buf-name (gethash project-root my/ghostel-posframe-buffers))
             (buf (when buf-name (get-buffer buf-name)))
             (parent (gethash project-root my/ghostel-posframe-visible)))
        (when buf-name
          (when buf
            (my/ghostel-posframe--undedicate-windows buf))
          (posframe-hide buf-name)
          (when my/ghostel-posframe--saved-window-config
            (set-window-configuration my/ghostel-posframe--saved-window-config)
            (setq my/ghostel-posframe--saved-window-config nil))
          (when (and parent (frame-live-p parent))
            (x-focus-frame parent))
          (puthash project-root nil my/ghostel-posframe-visible))))

    (defun my/ghostel-posframe-toggle ()
      "Toggle a floating ghostel terminal scoped to the current project."
      (interactive)
      (let* ((project-root (my/ghostel-posframe--project-root))
             (visible (gethash project-root my/ghostel-posframe-visible)))
        (if visible
            (my/ghostel-posframe--hide project-root)
          (my/ghostel-posframe--show project-root))))

    (defun my/ghostel-posframe-kill ()
      "Kill the floating ghostel terminal for the current project and clean up."
      (interactive)
      (let* ((project-root (my/ghostel-posframe--project-root))
             (buf-name (gethash project-root my/ghostel-posframe-buffers))
             (buf (when buf-name (get-buffer buf-name))))
        (when buf-name
          (when buf (my/ghostel-posframe--undedicate-windows buf))
          (posframe-delete buf-name)
          (when (buffer-live-p buf) (kill-buffer buf))
          (remhash project-root my/ghostel-posframe-buffers)
          (remhash project-root my/ghostel-posframe-visible)
          (when my/ghostel-posframe--saved-window-config
            (set-window-configuration my/ghostel-posframe--saved-window-config)
            (setq my/ghostel-posframe--saved-window-config nil)))))

    (evil-leader/set-key
      "tp" 'my/ghostel-posframe-toggle
      "tP" 'my/ghostel-posframe-kill)
  '';
}
