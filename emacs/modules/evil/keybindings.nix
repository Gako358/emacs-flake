_:
{
  order = 1100;
  elisp = ''
    ;;; Keybindings
      ;; Kill all buffers except current working buffer
      (defun kill-other-buffers ()
        "Kill all buffers except the current one.
      Forcibly kills buffers that have a live process (vterm, term, shell,
      eshell, compilation, ...) by suppressing the kill-buffer query
      functions and disabling each process' query-on-exit flag. Also hides
      any posframe attached to a buffer (e.g. the floating vterm) and
      skips the minibuffer and internal hidden buffers (those whose name
      starts with a space)."
        (interactive)
        (let ((current (current-buffer))
              (kill-buffer-query-functions nil)
              (killed 0))
          (dolist (buf (buffer-list))
            (unless (or (eq buf current)
                        (minibufferp buf)
                        (string-prefix-p " " (buffer-name buf)))
              ;; Hide any posframe attached to the buffer (e.g. vterm posframe).
              (when (fboundp 'posframe-hide)
                (ignore-errors (posframe-hide (buffer-name buf))))
              ;; Disable query on exit for any live processes.
              (when-let ((proc (get-buffer-process buf)))
                (set-process-query-on-exit-flag proc nil))
              (when (ignore-errors (kill-buffer buf))
                (setq killed (1+ killed)))))
          (message "Killed %d buffer(s); kept %s"
                   killed (buffer-name current))))

      ;; Kill all dired buffers
      (defun kill-dired-buffers ()
        "Kill every buffer whose major mode is `dired-mode'."
        (interactive)
        (mapc (lambda (buffer)
                (when (eq 'dired-mode (buffer-local-value 'major-mode buffer))
                  (kill-buffer buffer)))
              (buffer-list)))

      ;; Toggle "fullscreen" for the selected window: maximize it, then on the
      ;; next invocation restore the exact previous window layout. The saved
      ;; configuration is kept in a frame parameter so it works per-frame.
      (defun my/toggle-maximize-window ()
        "Maximize the selected window, or restore the previous layout.
      The first call saves the current window configuration and deletes
      the other windows (making the current one fill the frame). The next
      call restores the saved side-by-side (or any) layout."
        (interactive)
        (let ((saved (frame-parameter nil 'my/window-maximized-config)))
          (if saved
              (progn
                (set-window-configuration saved)
                (set-frame-parameter nil 'my/window-maximized-config nil))
            (if (one-window-p)
                (message "Only one window in this frame; nothing to maximize.")
              (set-frame-parameter nil 'my/window-maximized-config
                                   (current-window-configuration))
              (delete-other-windows)))))

      ;; Also expose it under the evil window prefix: `C-w m'.
      (with-eval-after-load 'evil
        (define-key evil-window-map (kbd "m") 'my/toggle-maximize-window))

      (evil-leader/set-key
        "DEL" 'kill-buffer
        "ka"  'kill-other-buffers
        "kd"  'kill-dired-buffers
        "tr"  'rename-buffer
        "wm"  'my/toggle-maximize-window)
  '';
}
