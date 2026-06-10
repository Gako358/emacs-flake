_:
{
  order = 1600;
  elisp = ''
    ;;; Projects
    (use-package projectile
      :ensure t
      :defer 1
      :init
      (projectile-mode +1)
      :config
      (setq projectile-enable-caching t
  	  projectile-completion-system 'default
  	  projectile-indexing-method 'alien
  	  projectile-sort-order 'recently-active
  	  projectile-project-search-path '(("~/Projects/" . 1)
  					   ("~/Projects/forks/" . 1)
  					   ("~/Projects/workspace/" . 1)
  					   ("~/Sources/" . 1)))

      (defun projectile-kill-other-buffers ()
        "Kill all buffers in current project except for the current buffer."
        (interactive)
        (let ((current (current-buffer))
              (kill-buffer-query-functions nil))
          (dolist (buffer (projectile-project-buffers))
            (unless (eq buffer current)
              (when-let ((proc (get-buffer-process buffer)))
                (set-process-query-on-exit-flag proc nil))
              (ignore-errors (kill-buffer buffer))))))

      (evil-leader/set-key
        "kp" 'projectile-kill-other-buffers
        "pc" 'projectile-cleanup-known-projects
        "pd" 'projectile-discover-projects-in-search-path))
  '';
}
