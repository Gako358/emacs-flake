_:
{
  order = 104;
  elisp = ''
    ;;; Modeline
  (use-package spaceline
    :ensure t
    :init
    (setq spaceline-buffer-encoding-abbrev-p nil
  	  spaceline-line-column-p nil
  	  spaceline-line-p nil
  	  powerline-default-separator 'arrow
  	  powerline-gui-use-vcs-glyph t
  	  powerline-height 28
  	  spaceline-highlight-face-func 'spaceline-highlight-face-modified
  	  spaceline-workspace-numbers-unicode t
  	  spaceline-window-numbers-unicode t
  	  spaceline-separator-dir-left '(left . right)
  	  spaceline-separator-dir-right '(right . left))
    :config
    (require 'spaceline-config)

    ;; Version control segment
    (spaceline-define-segment nasy:version-control
      "Version control information."
      (when vc-mode
        (let ((branch (mapconcat 'concat (cdr (split-string vc-mode "[:-]")) "-")))
          (powerline-raw
           (s-trim (concat "  "
                           branch
                           (when (buffer-file-name)
                             (pcase (vc-state (buffer-file-name))
                               (`up-to-date " ✓")
                               (`edited " ❓")
                               (`added " ➕")
                               (`unregistered " ■")
                               (`removed " ✘")
                               (`needs-merge " ↓")
                               (`needs-update " ↑")
                               (`ignored " ✦")
                               (_ " ⁇")))))))))

    ;; Time segment
    (spaceline-define-segment nasy-time
      "Time"
      (format-time-string "%b %d, %Y - %H:%M ")
      :tight-right t)

    ;; Activate theme with custom segments
    (spaceline-spacemacs-theme 'nasy:version-control 'nasy-time))
  '';
}
