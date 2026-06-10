_:
{
  order = 1502;
  elisp = ''
    ;;; Org-Msg
    (use-package org-msg
      :ensure t
      :after mu4e
      :config
      (setq mail-user-agent 'mu4e-user-agent)
      (require 'org-msg)
      (setq org-msg-options "html-postamble:nil H:5 num:nil ^:{} toc:nil author:nil email:nil \\n:t"
  	  org-msg-startup "hidestars indent inlineimages"
  	  org-msg-default-alternatives '((new               . (text html))
  					 (reply-to-html     . (text html))
  					 (reply-to-text     . (text)))
  	  org-msg-convert-citation t)

      (defun my-org-msg-signature ()
        "Return a formatted signature for org-msg emails."
        (concat "\n\n"
                "Best regards,\n"
                "*Knut Oien*\n"
                "/Senior Software Engineer HNIKT/\n"))

      (setq org-msg-signature (my-org-msg-signature))

      (defun my-update-from-header-in-org-msg ()
        "Update the From header in org-msg buffer to use the current user-mail-address."
        (setq org-msg-signature (my-org-msg-signature))
        (save-excursion
          (goto-char (point-min))
          (when (re-search-forward "^From: .*$" nil t)
            (replace-match (format "From: %s <%s>" user-full-name user-mail-address)))))

      (add-hook 'org-msg-edit-mode-hook 'my-update-from-header-in-org-msg)
      (org-msg-mode))
  '';
}
