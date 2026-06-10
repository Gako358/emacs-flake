_:
{
  order = 500;
  elisp = ''
  ;;; Edit
  ;; Formatters
  (use-package apheleia
    :ensure t
    :hook (after-init . apheleia-global-mode)
    :config
    ;; Register external formatter binaries.
    (dolist (fmt '((scalafmt           . ("scalafmt" "--stdin" "--non-interactive" "--quiet" "--stdout"))
                   (black              . ("black" "-"))
                   (prettier           . ("prettier" "--stdin-filepath" buffer-file-name))
                   (google-java-format . ("google-java-format" "-"))
                   (nixfmt             . ("nixfmt"))))
      (push fmt apheleia-formatters))

    ;; Map major modes -> formatter id.
    (dolist (m '((scala-ts-mode      . scalafmt)
                 (python-mode        . black)
                 (typescript-ts-mode . prettier)
                 (js-ts-mode         . prettier)
                 (vue-ts-mode        . prettier)
                 (java-ts-mode       . google-java-format)
                 (nix-ts-mode        . nixfmt)))
      (push m apheleia-mode-alist)))
  '';
}
