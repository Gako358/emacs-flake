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
    (setq mu4e-alert-email-notification-types '(count subjects))
    (setq mu4e-alert-interesting-mail-query
  	  "flag:unread AND NOT flag:trashed")
    (mu4e-alert-enable-mode-line-display)
    (mu4e-alert-enable-notifications))
  '';
}
