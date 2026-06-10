_:
{
  order = 1802;
  elisp = ''
    ;;; Vterm
    (use-package vterm
      :ensure t
      :commands vterm
      :custom
      (vterm-kill-buffer-on-exit t)
      (vterm-max-scrollback 10000)
      (vterm-clear-scrollback-when-clearing t)
      (vterm-copy-mode-remove-fake-newlines t)
      :config
      (setq vterm-buffer-name-string "vterm: %s"))

    (use-package vterm-toggle
      :ensure t
      :after vterm
      :custom
      (vterm-toggle-fullscreen-p nil)
      (vterm-toggle-scope 'project)
      :config
      (setq vterm-toggle-hide-method 'reset-window-configration))

    (defun my/vterm-in-project-root ()
      "Open vterm in the project root directory."
      (interactive)
      (let ((default-directory (or (projectile-project-root)
                                   default-directory)))
        (vterm)))

    (defun my/projectile-switch-to-buffer-with-vterm ()
      "Switch to a buffer whose name includes 'vterm using consult-projectile."
      (interactive)
      (let ((filtered-buffers (seq-filter (lambda (buf)
      					  (string-match-p "vterm" (buffer-name buf)))
      					(projectile-project-buffers))))
        (if filtered-buffers
      	  (consult--read (mapcar #'buffer-name filtered-buffers)
      			 :prompt "Switch to terminal: "
      			 :require-match t
      			 :sort nil
      			 :category 'buffer
      			 :history 'buffer-name-history
      			 :state (consult--buffer-state))
          (message "No buffers found with term: %s" "vterm"))))

    (evil-leader/set-key
      "tt" 'vterm-toggle
      "tn" 'my/vterm-in-project-root
      "td" 'vterm
      "to" 'vterm-other-window
      "tl" 'my/projectile-switch-to-buffer-with-vterm
      "tk" (lambda () (interactive)
  	   (when (get-buffer-process (current-buffer))
  	     (vterm-send-key "c" nil nil t))))

    (evil-leader/set-key
      "tc" 'vterm-toggle-cd
      "tf" 'vterm-toggle-forward
      "tb" 'vterm-toggle-backward)

    ;; --- Project-scoped toggleable vterm posframe ---
    (use-package posframe :ensure t)

    (defvar my/vterm-posframe-buffers (make-hash-table :test 'equal)
      "Hash table mapping project root paths to their vterm buffer names.")

    (defvar my/vterm-posframe-visible (make-hash-table :test 'equal)
      "Hash table tracking whether the posframe is currently visible for a project.")

    (defvar my/vterm-posframe--saved-window-config nil
      "Saved window configuration before showing the posframe.")

    (defcustom my/vterm-posframe-width-ratio 0.8
      "Width of the floating vterm as a ratio of the frame width."
      :type 'float)

    (defcustom my/vterm-posframe-height-ratio 0.6
      "Height of the floating vterm as a ratio of the frame height."
      :type 'float)

    (defun my/vterm-posframe--project-root ()
      "Return the current project root, falling back to `default-directory'."
      (or (projectile-project-root) default-directory))

    (defun my/vterm-posframe--buffer-name (project-root)
      "Return the vterm buffer name for PROJECT-ROOT."
      (format "*vterm-posframe[%s]*" (abbreviate-file-name project-root)))

    (defun my/vterm-posframe--get-or-create-buffer (project-root)
      "Get or create a vterm buffer for PROJECT-ROOT."
      (let* ((buf-name (my/vterm-posframe--buffer-name project-root))
             (existing (gethash project-root my/vterm-posframe-buffers)))
        (when (and existing (not (buffer-live-p (get-buffer existing))))
          (remhash project-root my/vterm-posframe-buffers)
          (remhash project-root my/vterm-posframe-visible)
          (setq existing nil))
        (if existing
            existing
          (let ((default-directory project-root))
            (let ((buf (generate-new-buffer buf-name)))
              (with-current-buffer buf
                (vterm-mode))
              (puthash project-root (buffer-name buf) my/vterm-posframe-buffers)
              (puthash project-root nil my/vterm-posframe-visible)
              (buffer-name buf))))))

    (defun my/vterm-posframe--undedicate-windows (buf)
      "Remove window dedication from all windows showing BUF.
      Vterm sets `window-dedicated-p' which blocks `set-window-configuration'."
      (dolist (win (get-buffer-window-list buf t t))
        (set-window-dedicated-p win nil)))

    (defun my/vterm-posframe--show (project-root)
      "Show the vterm posframe for PROJECT-ROOT."
      (let* ((buf-name (my/vterm-posframe--get-or-create-buffer project-root))
             (buf (get-buffer buf-name))
             (width (round (* (frame-width) my/vterm-posframe-width-ratio)))
             (height (round (* (frame-height) my/vterm-posframe-height-ratio)))
             (parent (selected-frame)))
        (setq my/vterm-posframe--saved-window-config (current-window-configuration))
        (my/vterm-posframe--undedicate-windows buf)
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
            (my/vterm-posframe--undedicate-windows buf)))
        (puthash project-root parent my/vterm-posframe-visible)))

    (defun my/vterm-posframe--hide (project-root)
      "Hide the vterm posframe for PROJECT-ROOT."
      (let* ((buf-name (gethash project-root my/vterm-posframe-buffers))
             (buf (when buf-name (get-buffer buf-name)))
             (parent (gethash project-root my/vterm-posframe-visible)))
        (when buf-name
          (when buf
            (my/vterm-posframe--undedicate-windows buf))
          (posframe-hide buf-name)
          (when my/vterm-posframe--saved-window-config
            (set-window-configuration my/vterm-posframe--saved-window-config)
            (setq my/vterm-posframe--saved-window-config nil))
          (when (and parent (frame-live-p parent))
            (x-focus-frame parent))
          (puthash project-root nil my/vterm-posframe-visible))))

    (defun my/vterm-posframe-toggle ()
      "Toggle a floating vterm scoped to the current project."
      (interactive)
      (let* ((project-root (my/vterm-posframe--project-root))
             (visible (gethash project-root my/vterm-posframe-visible)))
        (if visible
            (my/vterm-posframe--hide project-root)
          (my/vterm-posframe--show project-root))))

    (defun my/vterm-posframe-kill ()
      "Kill the floating vterm for the current project and clean up."
      (interactive)
      (let* ((project-root (my/vterm-posframe--project-root))
             (buf-name (gethash project-root my/vterm-posframe-buffers))
             (buf (when buf-name (get-buffer buf-name))))
        (when buf-name
          (when buf (my/vterm-posframe--undedicate-windows buf))
          (posframe-delete buf-name)
          (when (buffer-live-p buf) (kill-buffer buf))
          (remhash project-root my/vterm-posframe-buffers)
          (remhash project-root my/vterm-posframe-visible)
          (when my/vterm-posframe--saved-window-config
            (set-window-configuration my/vterm-posframe--saved-window-config)
            (setq my/vterm-posframe--saved-window-config nil)))))

    (evil-leader/set-key
      "tp" 'my/vterm-posframe-toggle
      "tP" 'my/vterm-posframe-kill)
  '';
}
