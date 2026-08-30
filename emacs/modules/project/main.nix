_:
{
  order = 1600;
  elisp = ''
    ;;; Projects
    (require 'project)

    (defun merrinx/project-find-file-other-window ()
      "Find a project file without displaying it in the selected window."
      (interactive)
      (let ((display-buffer-overriding-action
             '((display-buffer-pop-up-window)
               (inhibit-same-window . t))))
        (call-interactively #'project-find-file)))

    (defun merrinx/project-kill-other-buffers ()
      "Kill buffers in the current project except the current buffer."
      (interactive)
      (when-let* ((project (project-current))
                  (root (project-root project)))
        (when (and (stringp root)
                   (not (file-remote-p root)))
          (let ((current (current-buffer)))
            (dolist (buffer (buffer-list))
              (unless (eq buffer current)
                (with-current-buffer buffer
                  (let ((directory default-directory))
                    (when (and (stringp directory)
                               (not (file-remote-p directory))
                               (equal (project-current nil directory) project))
                      (let* ((file (buffer-file-name))
                             (modified (buffer-modified-p))
                             (process (get-buffer-process buffer))
                             (live-process (process-live-p process))
                             (statuses (delq nil (list (when modified "modified")
                                                       (when (and live-process
                                                                  (not (process-query-on-exit-flag process)))
                                                         "live process")))))
                        (when (or (null statuses)
                                  (y-or-n-p
                                   (format "Kill %s%s%s? "
                                           (buffer-name)
                                           (if file
                                               (format " (%s)" (abbreviate-file-name file))
                                             "")
                                           (if statuses
                                               (format " [%s]" (mapconcat #'identity statuses ", "))
                                             ""))))
                          (kill-buffer buffer))))))))))))

    (defcustom merrinx/project-discovery-roots
      '("Projects" "Projects/forks" "Projects/workspace" "Sources")
      "Directories below HOME in which to discover projects."
      :type '(repeat directory))

    (defcustom merrinx/project-discovery-depth 1
      "Maximum number of directory levels below each discovery root."
      :type 'integer)

    (defun merrinx/project-discover-projects ()
      "Remember local projects below the configured HOME-relative roots."
      (interactive)
      (let ((raw-home (getenv "HOME")))
        (when (and (stringp raw-home)
                   (not (string= raw-home ""))
                   (file-name-absolute-p raw-home)
                   (not (file-remote-p raw-home)))
          (let* ((home (file-name-as-directory
                        (file-truename (expand-file-name raw-home))))
                 (seen-depth (make-hash-table :test 'equal))
                 (remembered (make-hash-table :test 'equal)))
            (cl-labels ((safe-root (relative)
                          (when (and home (stringp relative)
                                     (not (file-name-absolute-p relative))
                                     (not (member ".." (split-string relative "/" t))))
                            (let ((candidate (expand-file-name relative home)))
                              (when (and (not (file-remote-p candidate))
                                         (file-in-directory-p candidate home))
                                candidate))))
                        (visit (dir depth root)
                          (when (and (<= depth merrinx/project-discovery-depth)
                                     (not (file-remote-p dir))
                                     (file-directory-p dir))
                            (let* ((canonical (file-name-as-directory
                                               (file-truename dir)))
                                   (remaining (- merrinx/project-discovery-depth depth))
                                   (previous (gethash canonical seen-depth)))
                              (when (and (not (file-remote-p canonical))
                                         (file-in-directory-p canonical root)
                                         (or (null previous)
                                             (> remaining previous)))
                                (puthash canonical remaining seen-depth)
                                (unless (gethash canonical remembered)
                                  (puthash canonical t remembered)
                                  (when-let* ((project (project-current nil canonical)))
                                    (project-remember-project project)))
                                (when (< depth merrinx/project-discovery-depth)
                                  (dolist (child (directory-files canonical t "^[^.].*" t))
                                    (when (and (not (file-remote-p child))
                                               (file-directory-p child))
                                      (visit child (1+ depth) root)))))))))
              (dolist (relative-root merrinx/project-discovery-roots)
                (when-let* ((root (safe-root relative-root)))
                  (when (and (not (file-remote-p root))
                             (file-directory-p root))
                    (let ((canonical-root (file-name-as-directory
                                           (file-truename root))))
                      (when (and (not (file-remote-p canonical-root))
                                 (file-in-directory-p canonical-root home))
                        (visit canonical-root 0 canonical-root)))))))))))

    (defun merrinx/project-cleanup-known-projects ()
      "Forget known local projects whose directories no longer exist."
      (interactive)
      (dolist (root (project-known-project-roots))
        (unless (file-remote-p root)
          (unless (file-directory-p root)
            (project-forget-project root)))))

    (evil-leader/set-key
      "kp" #'merrinx/project-kill-other-buffers
      "pc" #'merrinx/project-cleanup-known-projects
      "pd" #'merrinx/project-discover-projects)
  '';
}
