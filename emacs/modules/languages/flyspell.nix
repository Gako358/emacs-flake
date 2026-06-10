_:
{
  order = 901;
  elisp = ''
    ;;; Flyspell dictionary
      (use-package flyspell
        :ensure nil
        :init
        (setq ispell-program-name "hunspell")
        :config
        ;; The actual dictionary names based on the .aff files found
        (setq ispell-local-dictionary-alist
      	'(("en_GB" "[[:alpha:]]" "[^[:alpha:]]" "[']" nil ("-d" "en_GB") nil utf-8)
      	  ("nb_NO" "[[:alpha:]]" "[^[:alpha:]]" "[']" nil ("-d" "nb_NO") nil utf-8)))

        ;; Set default dictionary (use en_GB, not en_GB-ise)
        (setq ispell-dictionary "en_GB"
      	ispell-local-dictionary "en_GB")

        ;; Tell hunspell to use multiple dictionaries if needed
        (setq ispell-hunspell-dictionary-alist ispell-local-dictionary-alist)

        ;; Hooks to enable flyspell in the desired modes
        (dolist (hook '(org-mode-hook text-mode-hook markdown-mode-hook))
          (add-hook hook #'flyspell-mode))

        ;; Dictionary switching functions
        (defun my/switch-to-english ()
          "Switch to British English dictionary."
          (interactive)
          (ispell-change-dictionary "en_GB")
          (setq ispell-dictionary "en_GB"
      	    ispell-local-dictionary "en_GB")
          (when (bound-and-true-p flyspell-mode)
      	(flyspell-buffer))
          (message "Switched to British English (en_GB)"))

        (defun my/switch-to-norwegian ()
          "Switch to Norwegian Bokmål dictionary."
          (interactive)
          (ispell-change-dictionary "nb_NO")
          (setq ispell-dictionary "nb_NO"
        	  ispell-local-dictionary "nb_NO")
          (when (bound-and-true-p flyspell-mode)
            (flyspell-buffer))
          (message "Switched to Norwegian Bokmål (nb_NO)"))

        (defun my/toggle-dictionary ()
          "Toggle between British English and Norwegian dictionaries."
          (interactive)
          (let ((cur (or ispell-current-dictionary ispell-local-dictionary ispell-dictionary)))
            (if (string= cur "en_GB")
        	  (my/switch-to-norwegian)
        	(my/switch-to-english))))

        ;; Keybindings for switching
        (global-set-key (kbd "C-c d e") #'my/switch-to-english)
        (global-set-key (kbd "C-c d n") #'my/switch-to-norwegian)
        (global-set-key (kbd "C-c d t") #'my/toggle-dictionary)

        ;; If hunspell is available, prefer it explicitly
        (when (executable-find "hunspell")
          (setq ispell-really-hunspell t)))
  '';
}
