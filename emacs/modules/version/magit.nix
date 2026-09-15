_:
{
  order = 1905;
  elisp = ''
    ;;; Magit
    (use-package magit
      :ensure t
      :defer t
      :commands magit-status
      :custom
      (magit-read-worktree-directory-function
       #'magit-read-worktree-directory-offsite)
      (magit-read-worktree-offsite-directory
       (expand-file-name "~/Projects/worktrees/"))
      :init
      (evil-leader/set-key
        "/" 'magit-status)
      :config
      (defun merrinx/magit-remember-worktree-project (directory &rest _)
        "Remember the project rooted at a newly created worktree DIRECTORY."
        (when (file-directory-p directory)
          (when-let* ((project (project-current nil directory)))
            (project-remember-project project))))

      (defun merrinx/magit-forget-worktree-project (worktree &rest _)
        "Forget the project rooted at a removed WORKTREE."
        (unless (file-directory-p worktree)
          (project-forget-project
           (file-name-as-directory (expand-file-name worktree)))))

      (with-eval-after-load 'magit-worktree
        (advice-add #'magit-worktree-checkout :after
                    #'merrinx/magit-remember-worktree-project)
        (advice-add #'magit-worktree-branch :after
                    #'merrinx/magit-remember-worktree-project)
        (advice-add #'magit-worktree-delete :after
                    #'merrinx/magit-forget-worktree-project)))
  '';
}
