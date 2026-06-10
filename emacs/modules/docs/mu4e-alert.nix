_:
{
  order = 602;
  elisp = ''
  ;;; Mu4e-Alert
  (use-package mu4e-alert
    :ensure t
    :after mu4e
    :config
    (mu4e-alert-set-default-style 'notifications)
    (add-hook 'after-init-hook #'mu4e-alert-enable-mode-line-display)
    (add-hook 'after-init-hook #'mu4e-alert-enable-notifications)
    (setq mu4e-alert-email-notification-types '(count subjects))
    (setq mu4e-alert-interesting-mail-query
  	  "flag:unread AND NOT flag:trashed"))
  '';
}
