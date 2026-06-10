_:
{
  order = 1906;
  elisp = ''
    ;;; Consult-GH
    (use-package consult-gh
      :ensure t
      :after (consult forge)
      :commands (consult-gh
                 consult-gh-search-repos
                 consult-gh-search-prs
                 consult-gh-search-issues
                 consult-gh-search-code
                 consult-gh-orgs
                 consult-gh-repo-list
                 consult-gh-issue-list
                 consult-gh-pr-list
                 consult-gh-transient)
      :init
      (evil-leader/set-key
        "Gr" 'consult-gh-search-repos
        "Gp" 'consult-gh-search-prs
        "Gi" 'consult-gh-search-issues
        "Gc" 'consult-gh-search-code
        "Go" 'consult-gh-orgs
        "GG" 'consult-gh-transient)
      :config
      (require 'consult-gh-transient)

      (setq consult-gh-default-clone-directory "~/Sources/"
            consult-gh-preview-key "M-o"
            consult-gh-forge-timeout-seconds 20)

      (defun my/consult-gh-pr-review-action (cand)
        "Open the selected consult-gh PR CAND in `pr-review'."
        (let ((url (and (stringp cand)
                        (or (get-text-property 0 :url cand)
                            (let ((repo   (get-text-property 0 :repo cand))
                                  (number (get-text-property 0 :number cand)))
                              (when (and repo number)
                                (format "https://github.com/%s/pull/%s"
                                        repo number)))))))
          (if (and url (fboundp 'pr-review-open-url))
              (pr-review-open-url url)
            (consult-gh--pr-view-action cand))))
      (setq consult-gh-pr-action #'my/consult-gh-pr-review-action)

      (with-eval-after-load 'evil
        (evil-ex-define-cmd "ghr" #'consult-gh-search-repos)
        (evil-ex-define-cmd "ghp" #'consult-gh-search-prs)
        (evil-ex-define-cmd "ghi" #'consult-gh-search-issues)
        (evil-ex-define-cmd "ghc" #'consult-gh-search-code)))

    (use-package consult-gh-embark
      :ensure t
      :after consult-gh
      :config
      (consult-gh-embark-mode +1))

    (use-package consult-gh-forge
      :ensure t
      :after consult-gh
      :config
      (consult-gh-forge-mode +1)
      ;; Issues -> open in a Magit/Forge buffer.
      (setq consult-gh-issue-action #'consult-gh-forge--issue-view-action))
  '';
}
