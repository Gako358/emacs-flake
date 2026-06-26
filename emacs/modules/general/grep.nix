_:
{
  order = 804;
  elisp = ''
    ;;; Grep
    (use-package wgrep
      :ensure t
      :defer t
      :commands (wgrep-change-to-wgrep-mode wgrep-finish-edit)
      :init
      (with-eval-after-load 'evil-leader
        (evil-leader/set-key
          "fe" 'wgrep-change-to-wgrep-mode
          "fs" 'wgrep-finish-edit)))

    ;; Find files by name under a prompted root — SPC f F.
    ;; SPC f f stays as consult-find (from current dir, see navigation/main.nix).
    (defun my/find-files-from-root ()
      "Prompt for a root directory then search for files by name with `consult-fd'.
Accepts ~/, ~/.config, /home/merrinx/, etc.
Results support `embark-collect' (C-c C-o) for a persistent list."
      (interactive)
      (let ((default-directory
             (expand-file-name
              (read-directory-name "Find files in: " "~/" nil t))))
        (if (fboundp 'consult-fd)
            (consult-fd)
          (consult-find))))

    ;; Grep in files under a prompted root — SPC f G.
    ;; SPC f g stays as consult-ripgrep (from current dir, see navigation/main.nix).
    (defun my/grep-in-files-from-root ()
      "Prompt for a root directory then grep with `consult-ripgrep'.
Accepts ~/, ~/.config, /home/merrinx/, etc.
Results support `embark-collect' (C-c C-o) for a persistent list."
      (interactive)
      (consult-ripgrep
       (expand-file-name
        (read-directory-name "Grep files in: " "~/" nil t))))

    (with-eval-after-load 'evil-leader
      (evil-leader/set-key
        "fF" 'my/find-files-from-root
        "fG" 'my/grep-in-files-from-root))
  '';
}
