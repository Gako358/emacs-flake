_:
{
  order = 1504;
  elisp = ''
    ;;; Org planning
    (require 'org-id)

    (defun merrinx/org-planning--notes-directory ()
      (or (and (boundp 'org-roam-directory) org-roam-directory)
          (file-truename "~/Documents/notes")))

    (defun merrinx/org-planning--canonical-file ()
      (expand-file-name "tasks.org"
                        (file-name-as-directory
                         (merrinx/org-planning--notes-directory))))

    (defun merrinx/org-planning--heading-count (heading)
      (save-excursion
        (goto-char (point-min))
        (let ((count 0))
          (while (re-search-forward
                  (format "^\\* %s[ \\t]*$" (regexp-quote heading)) nil t)
            (setq count (1+ count)))
          count)))

    (defun merrinx/org-planning--validate-headings (headings)
      (dolist (heading headings)
        (pcase (merrinx/org-planning--heading-count heading)
          (1 nil)
          (0 (user-error "Missing top-level heading: %s" heading))
          (_ (user-error "Duplicate top-level heading: %s" heading)))))

    (defun merrinx/org-planning-ensure-tasks-file ()
      (let* ((file (merrinx/org-planning--canonical-file))
             (buffer (get-file-buffer file)))
        (cond
         (buffer
          (with-current-buffer buffer
            (save-restriction
              (widen)
              (if (file-exists-p file)
                  (merrinx/org-planning--validate-headings '("Inbox" "Actions"))
                (user-error "Visiting tasks file has no backing file: %s" file))))
          file)
         ((file-exists-p file)
          (with-temp-buffer
            (insert-file-contents file)
            (merrinx/org-planning--validate-headings '("Inbox" "Actions")))
          file)
         (t
          (make-directory (file-name-directory file) t)
          (write-region "#+title: Tasks\n\n* Inbox\n\n* Actions\n"
                        nil file nil 'silent)
          file))))

    (defun merrinx/org-planning-open-tasks ()
      (interactive)
      (let ((file (merrinx/org-planning-ensure-tasks-file)))
        (find-file file)
        (widen)
        (org-fold-show-all)))

    (setq org-todo-keywords
          '((sequence "TODO(t)" "NEXT(n)" "WAIT(w)" "|" "DONE(d)" "CANCELLED(c)"))
          org-log-done 'time
          org-refile-targets
          '((merrinx/org-planning-ensure-tasks-file :maxlevel . 1))
          org-capture-templates
          '(("t" "Task" entry
             (file+olp merrinx/org-planning-ensure-tasks-file "Inbox")
             "* TODO %?\n  %U\n  %a"))
          org-id-link-to-org-use-id 'create-if-interactive
          org-id-extra-files (list (merrinx/org-planning--canonical-file)))

    (defun merrinx/org-planning-capture-task ()
      (interactive)
      (org-capture nil "t"))

    (defun merrinx/org-planning--append-heading (heading)
      (goto-char (point-max))
      (unless (bolp) (insert "\n"))
      (insert "\n* " heading "\n"))

    (defun merrinx/org-planning-day ()
      (interactive)
      (require 'org-roam-dailies)
      (org-roam-dailies-goto-today "d")
      (let ((expected (expand-file-name
                       (format-time-string "%Y-%m-%d.org")
                       (expand-file-name org-roam-dailies-directory
                                         (merrinx/org-planning--notes-directory)))))
        (unless (and buffer-file-name
                     (string-equal (expand-file-name buffer-file-name) expected)
                     (not (derived-mode-p 'org-capture-mode)))
          (user-error "Org-roam did not select today's daily file"))
        (save-restriction
          (widen)
          (pcase (merrinx/org-planning--heading-count "Top 3")
            (0 (merrinx/org-planning--append-heading "Top 3"))
            (1 nil)
            (_ (user-error "Duplicate top-level heading: Top 3"))))))

    (defun merrinx/org-planning-week (&optional time)
      (interactive)
      (let* ((name (format-time-string "%G-W%V.org" time))
             (directory (expand-file-name
                         "Planning/"
                         (file-name-as-directory
                          (merrinx/org-planning--notes-directory))))
             (file (expand-file-name name directory))
             (buffer (get-file-buffer file)))
        (unless (or buffer (file-exists-p file))
          (make-directory directory t)
          (write-region (format "#+title: %s\n\n* Outcomes\n\n* Review\n" name)
                        nil file nil 'silent))
        (find-file file)
        (widen)
        (save-restriction
          (widen)
          (let ((outcomes (merrinx/org-planning--heading-count "Outcomes"))
                (review (merrinx/org-planning--heading-count "Review")))
            (when (or (> outcomes 1) (> review 1))
              (user-error "Duplicate weekly planning heading"))
            (when (= outcomes 0) (merrinx/org-planning--append-heading "Outcomes"))
            (when (= review 0) (merrinx/org-planning--append-heading "Review"))))))

    (dolist (binding '(("n" . merrinx/org-planning-capture-task)
                       ("T" . merrinx/org-planning-open-tasks)
                       ("p" . merrinx/org-planning-day)
                       ("w" . merrinx/org-planning-week)
                       ("s" . org-store-link)))
      (let ((key (kbd (car binding)))
            (command (cdr binding)))
        (when (and (lookup-key org-prefix-map key)
                   (not (eq (lookup-key org-prefix-map key) command)))
          (user-error "Org prefix key is already occupied: %s" (car binding)))
        (define-key org-prefix-map key command)))
  '';
}
