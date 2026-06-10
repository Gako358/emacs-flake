_:
{
  order = 1503;
  elisp = ''
    ;;; Org-Roam
    (use-package org-roam
      :ensure t
      :defer t
      :init
      (setq org-roam-v2-ack t)
      (setq my/daily-note-filename "%<%Y-%m-%d>.org"
  	  my/daily-note-header "#+title: %<%Y-%m-%d %a>\n\n[[roam:%<%Y-%B>]]\n\n")
      :custom
      (org-roam-directory (file-truename "~/Documents/notes"))
      (org-roam-dailies-directory "Backlog/")
      (org-roam-completion-everywhere t)
      (org-roam-capture-templates
       '(("d" "default" plain "%?"
  	:if-new (file+head "%<%Y%m%d%H%M%S>-''${slug}.org"
  			   "#+title: ''${title}\n")
  	:unnarrowed t)))
      (org-roam-dailies-capture-templates
       `(("d" "default" entry
  	"* %?"
  	:if-new (file+head ,my/daily-note-filename
  			   ,my/daily-note-header))
         ("t" "task" entry
  	"* TODO %?\n  %U\n  %a\n  %i"
  	:if-new (file+head+olp ,my/daily-note-filename
  			       ,my/daily-note-header
  			       ("Tasks"))
  	:empty-lines 1)
         ("l" "log entry" entry
  	"* %<%I:%M %p> - %?"
  	:if-new (file+head+olp ,my/daily-note-filename
  			       ,my/daily-note-header
  			       ("Log")))
         ("j" "journal" entry
  	"* %<%I:%M %p> - Journal  :journal:\n\n%?\n\n"
  	:if-new (file+head+olp ,my/daily-note-filename
  			       ,my/daily-note-header
  			       ("Log")))
         ("m" "meeting" entry
  	"* %<%I:%M %p> - %^{Meeting Title}  :meetings:\n\n%?\n\n"
  	:if-new (file+head+olp ,my/daily-note-filename
  			       ,my/daily-note-header
  			       ("Log")))))
      :bind (:map org-mode-map
  		("C-M-i" . completion-at-point))
      :config
      (org-roam-setup)
      (org-roam-db-autosync-mode))

    (define-prefix-command 'org-prefix-map)
    (global-set-key (kbd "C-x o") 'org-prefix-map)
    (define-key org-prefix-map (kbd "l") 'org-roam-buffer-toggle)
    (define-key org-prefix-map (kbd "c") 'org-roam-capture)
    (define-key org-prefix-map (kbd "f") 'org-roam-node-find)
    (define-key org-prefix-map (kbd "i") 'org-roam-node-insert)
    (define-key org-prefix-map (kbd "d") 'org-roam-dailies-capture-date)
    (define-key org-prefix-map (kbd "t") 'org-roam-dailies-goto-today)
    (define-key org-prefix-map (kbd "y") 'org-roam-dailies-goto-yesterday)
    (define-key org-prefix-map (kbd "m") 'org-roam-dailies-goto-tomorrow)
  '';
}
