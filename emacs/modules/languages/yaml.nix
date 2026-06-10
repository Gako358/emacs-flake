_:
{
  order = 1218;
  elisp = ''
    ;;; Yaml
      ;; Ensure yaml-ts-mode is always enabled for YAML files
      (use-package yaml-ts-mode
        :ensure t
        :mode (("\\.yml\\'" . yaml-ts-mode)
    	 ("\\.yaml\\'" . yaml-ts-mode)))

      ;; Use-package configuration for yaml-pro with tree-sitter support
      (use-package yaml-pro
        :ensure t
        :after treesit
        :hook ((yaml-ts-mode . yaml-pro-ts-mode)
          	 (yaml-mode . yaml-ts-mode)
          	 (before-save . yaml-pro-format-buffer))
        :config
        ;; Add keybindings for tree-sitter mode
        (define-key yaml-pro-ts-mode-map (kbd "M-RET") #'yaml-pro-ts-meta-return)
        (define-key yaml-pro-ts-mode-map (kbd "M-?") #'yaml-pro-ts-convolute-tree)
        (define-key yaml-pro-ts-mode-map (kbd "C-c @") #'yaml-pro-ts-mark-subtree)
        (define-key yaml-pro-ts-mode-map (kbd "C-c C-x C-y") #'yaml-pro-ts-paste-subtree)
        ;; Pretty formatter keybinding
        (define-key yaml-pro-ts-mode-map (kbd "C-c C-f") #'yaml-pro-format)
        ;; Easy movement with repeat map
        (keymap-set yaml-pro-ts-mode-map "C-M-n" #'yaml-pro-ts-next-subtree)
        (keymap-set yaml-pro-ts-mode-map "C-M-p" #'yaml-pro-ts-prev-subtree)
        (keymap-set yaml-pro-ts-mode-map "C-M-u" #'yaml-pro-ts-up-level)
        (keymap-set yaml-pro-ts-mode-map "C-M-d" #'yaml-pro-ts-down-level)
        (keymap-set yaml-pro-ts-mode-map "C-M-k" #'yaml-pro-ts-kill-subtree)
        (keymap-set yaml-pro-ts-mode-map "C-M-<backspace>" #'yaml-pro-ts-kill-subtree)
        (keymap-set yaml-pro-ts-mode-map "C-M-a" #'yaml-pro-ts-first-sibling)
        (keymap-set yaml-pro-ts-mode-map "C-M-e" #'yaml-pro-ts-last-sibling)
        (defvar-keymap my/yaml-pro/tree-repeat-map
          :repeat t
          "n" #'yaml-pro-ts-next-subtree
          "p" #'yaml-pro-ts-prev-subtree
          "u" #'yaml-pro-ts-up-level
          "d" #'yaml-pro-ts-down-level
          "m" #'yaml-pro-ts-mark-subtree
          "k" #'yaml-pro-ts-kill-subtree
          "a" #'yaml-pro-ts-first-sibling
          "e" #'yaml-pro-ts-last-sibling
          "SPC" #'my/yaml-pro/set-mark)
        (defun my/yaml-pro/set-mark ()
          (interactive)
          (my/region/set-mark 'my/yaml-pro/set-mark))
        (defun my/region/set-mark (command-name)
          (if (eq last-command command-name)
          	(if (region-active-p)
          	    (progn
          	      (deactivate-mark)
          	      (message "Mark deactivated"))
          	  (activate-mark)
          	  (message "Mark activated"))
            (set-mark-command nil))))

      ;; Add hook to format YAML buffer before save
      (defun yaml-pro-format-buffer ()
        "Format the current buffer with yaml-pro-format."
        (when (derived-mode-p 'yaml-ts-mode)
          (yaml-pro-format)))

  '';
}
