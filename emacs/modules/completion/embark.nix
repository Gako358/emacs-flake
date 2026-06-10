_:
{
  order = 205;
  elisp = ''
    ;;; Embark
  (use-package embark
    ;; Embark is an Emacs package that acts like a context menu, allowing
    ;; users to perform context-sensitive actions on selected items
    ;; directly from the completion interface.
    :ensure t
    :defer t
    :commands (embark-act
  	     embark-dwim
  	     embark-export
  	     embark-collect
  	     embark-bindings
  	     embark-prefix-help-command)
    :init
    (setq prefix-help-command #'embark-prefix-help-command)

    :config
    ;; Hide the mode line of the Embark live/completions buffers
    (add-to-list 'display-buffer-alist
                 '("\\`\\*Embark Collect \\(Live\\|Completions\\)\\*"
                   nil
                   (window-parameters (mode-line-format . none))))
    :bind (:map minibuffer-local-map
                ("M-o"     . embark-act)
    	      ("M-O"     . embark-act-all)
                ("C-c C-c" . embark-export)
                ("C-c C-o" . embark-collect)))

  (use-package embark-consult
    :ensure t
    :after (embark consult))
  '';
}
