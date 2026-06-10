_:
{
  order = 1904;
  elisp = ''
    ;;; PR Review
    (use-package pr-review
      :ensure t
      :defer t
      :commands (pr-review pr-review-search pr-review-search-open
                           pr-review-notification pr-review-open-url)
      :init
      (evil-leader/set-key
        "Pn" 'pr-review-notification
        "Pp" 'pr-review
        "Ps" 'pr-review-search)
      :config
      (setq pr-review-forges-alist
            '(("github.com" . (github nil nil))))

      ;; Hide noisy bot review comments by default.
      (setq pr-review-default-hide-commenter
            '("codecov-bot" "codecov-commenter" "dependabot" "dependabot[bot]"
              "github-actions" "github-actions[bot]"))

      (with-eval-after-load 'evil
        (evil-ex-define-cmd "prr" #'pr-review)
        (evil-ex-define-cmd "prs" #'pr-review-search)
        (evil-ex-define-cmd "prn" #'pr-review-notification))

      ;; Make every browser-opened PR URL go through pr-review.
      (add-to-list 'browse-url-default-handlers
                   '(pr-review-url-parse . pr-review-open-url))

      ;; mu4e integration: from a GitHub notification email, hit C-c C-r
      ;; to launch pr-review on the PR mentioned in the message. Works on
      ;; both plain-text and HTML emails (mu4e renders HTML through shr,
      ;; and pr-review reads `shr-url' text properties).
      (with-eval-after-load 'mu4e
        (define-key mu4e-view-mode-map (kbd "C-c C-r") #'pr-review))
      (with-eval-after-load 'mu4e-view
        (when (boundp 'mu4e-view-mode-map)
          (define-key mu4e-view-mode-map (kbd "C-c C-r") #'pr-review))))
  '';
}
