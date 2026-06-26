_:
{
  order = 1000;
  elisp = ''
    ;;; Filetree
      (use-package dirvish
        :ensure t
        :defer t
        ;; Autoload these so SPC rf / M-x dirvish triggers loading lazily.
        :commands (dirvish dirvish-side dirvish-fd dirvish-dwim
                           dirvish-override-dired-mode)
        :init
        ;; Defer the global override until dired is first used. This avoids
        ;; loading dirvish (and its many deps) at startup, while still
        ;; transparently turning every subsequent dired buffer into dirvish.
        (with-eval-after-load 'dired
          (dirvish-override-dired-mode))
        (with-eval-after-load 'evil-leader
          (evil-leader/set-key "rf" 'dirvish))
        :custom
        ;; :custom is evaluated at use-package macroexpansion time, so these
        ;; take effect immediately — before dired/dirvish actually loads.
        (dirvish-mode-line-format '(:left (sort symlink) :right (omit yank index)))
        ;; The order *MATTERS* for some attributes.
        (dirvish-attributes '(vc-state subtree-state nerd-icons collapse git-msg file-time file-size))
        (dirvish-side-attributes '(vc-state nerd-icons collapse file-size))
        (delete-by-moving-to-trash t)
        (dired-listing-switches "-l --almost-all --human-readable --group-directories-first --no-group")
        :bind ; Bind `dirvish-fd|dirvish-side|dirvish-dwim' as you see fit
        (:map dirvish-mode-map           ; Dirvish inherits `dired-mode-map'
              ("M-f" . dirvish-file-info-menu)
              ("M-y" . dirvish-yank-menu)
              ("M-h" . dired-up-directory)
              ("M-n" . dired-create-empty-file)
              ("M-v" . dirvish-vc-menu)   ; remapped `dired-view-file'
              ("M-o" . dirvish-subtree-toggle)
              ("M-l" . dirvish-ls-switches-menu)
              ("M-m" . dirvish-mark-menu)
              ("M-t" . dirvish-layout-toggle)
              ("M-s" . dirvish-setup-menu)
              ("M-e" . dirvish-emerge-menu)
              ("M-q" . dirvish-quit)
              ("M-j" . dirvish-fd-jump))
        :hook
        (dirvish-setup . (lambda ()
                           (visual-line-mode -1)
                           (setq-local truncate-lines t))))

      ;; auto-revert in dired is generic (not dirvish-specific); set it
      ;; outside the use-package so it doesn't gate on dirvish loading.
      (add-hook 'dired-mode-hook 'auto-revert-mode)

      ;; Open dirvish at home by default; C-u SPC r d prompts for a path.
      ;; Kept under the SPC r prefix alongside SPC r f (dirvish); SPC t d is
      ;; already taken by ghostel (see terminal/ghostel.nix).
      (defun my/dirvish-open (&optional dir)
        "Open `dirvish' at DIR, defaulting to the home directory.
With a prefix arg (C-u), prompt for a root path — accepts
~/, ~/.config, /home/merrinx/, etc."
        (interactive
         (list (if current-prefix-arg
                   (expand-file-name
                    (read-directory-name "Open dirvish in: " "~/" nil t))
                 (expand-file-name "~/"))))
        (dirvish dir))

      (with-eval-after-load 'evil-leader
        (evil-leader/set-key "rd" 'my/dirvish-open))
  '';
}
