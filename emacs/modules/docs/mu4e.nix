_:
{
  order = 601;
  elisp = ''
  ;;; Mu4e
  (use-package mu4e
    :ensure t
    :defer 20
    :config
    (setq mu4e-change-filenames-when-moving t
  	  mu4e-update-interval (* 10 60)
  	  mu4e-compose-format-flowed t
  	  mu4e-get-mail-command "mbsync -a"
  	  mu4e-maildir "~/Mail")

    ;; Multiple accounts via mu4e contexts. The matching identity and folders
    ;; are selected automatically from the maildir a message lives in:
    ;;   ~/Mail/personal -> Proton (merrinx@proton.me)
    ;;   ~/Mail/work     -> Outlook/Microsoft 365 via the local DavMail gateway
    (setq mu4e-contexts
          (list
           (make-mu4e-context
            :name "personal"
            :match-func
            (lambda (msg)
              (when msg
                (string-prefix-p "/personal" (mu4e-message-field msg :maildir))))
            :vars '((user-mail-address . "merrinx@proton.me")
                    (user-full-name    . "merrinx")
                    (mu4e-drafts-folder . "/personal/Drafts")
                    (mu4e-sent-folder   . "/personal/Sent")
                    (mu4e-trash-folder  . "/personal/Trash")
                    (mu4e-refile-folder . "/personal/Archive")))
           (make-mu4e-context
            :name "work"
            :match-func
            (lambda (msg)
              (when msg
                (string-prefix-p "/work" (mu4e-message-field msg :maildir))))
            :vars '((user-mail-address . "knut.andre.guldseth.oien@hnikt.no")
                    (user-full-name    . "Knut André Guldseth Øien")
                    (mu4e-drafts-folder . "/work/Drafts")
                    (mu4e-sent-folder   . "/work/Sent")
                    (mu4e-trash-folder  . "/work/Trash")
                    (mu4e-refile-folder . "/work/Archive")))))

    ;; Pick the first matching context at startup; ask when composing a fresh
    ;; message that doesn't match any context.
    (setq mu4e-context-policy 'pick-first
          mu4e-compose-context-policy 'ask-if-none)

    (setq mu4e-maildir-shortcuts
          '(("/personal/INBOX"     . ?i)
            ("/personal/Sent"      . ?s)
            ("/personal/Trash"     . ?t)
            ("/personal/Drafts"    . ?d)
            ("/personal/Archive"   . ?a)
            ("/personal/All Mail"  . ?m)
            ("/personal/Spam"      . ?j)
            ("/personal/Starred"   . ?★)
            ("/work/INBOX"         . ?I)
            ("/work/Sent"          . ?S)
            ("/work/Trash"         . ?T)
            ("/work/Drafts"        . ?D)
            ("/work/Archive"       . ?A)))

    (setq send-mail-function 'sendmail-send-it
          message-send-mail-function 'sendmail-send-it
          sendmail-program "msmtp"
          message-sendmail-extra-arguments '("--read-envelope-from")
          message-sendmail-f-is-evil t)

    (setq user-mail-address "merrinx@proton.me"
          user-full-name "merrinx")

    (defun my-set-alias-when-replying ()
      "Automatically set the From address to match the To address of the message being replied to."
      (when mu4e-compose-parent-message
        (let* ((to-field (mu4e-message-field mu4e-compose-parent-message :to))
               (to-addr (when to-field
                          (caar to-field)))
               (aliases '("mugge.acrobat989@passinbox.com"
                          "gako.footwork856@passinbox.com"
                          "knut.sly692@passinbox.com")))
          (when (and to-addr (member to-addr aliases))
            (setq user-mail-address to-addr)
            (message "Replying with alias: %s" to-addr)))))

    (add-hook 'mu4e-compose-pre-hook 'my-set-alias-when-replying))
  '';
}
