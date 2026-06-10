_: {
  order = 801;
  elisp = ''
    ;;; Compilation
    (use-package compile
      :ensure nil  ;; built-in package
      :defer t
      :config
      ;; Add sbt error regexp patterns
      (add-to-list 'compilation-error-regexp-alist 'sbt-error)
      (add-to-list 'compilation-error-regexp-alist-alist
    			   '(sbt-error
    		 "^\\[error\\] -- .*?: \\([^:]+\\):\\([0-9]+\\):\\([0-9]+\\)" 1 2 3 2 1))

      (add-to-list 'compilation-error-regexp-alist 'sbt-warning)
      (add-to-list 'compilation-error-regexp-alist-alist
                   '(sbt-warning
                     "^\\[warn\\] -- .*?: \\([^:]+\\):\\([0-9]+\\):\\([0-9]+\\)" 1 2 3 1 1))

      ;; Pattern for line-only errors (no column number)
      (add-to-list 'compilation-error-regexp-alist 'sbt-error-simple)
      (add-to-list 'compilation-error-regexp-alist-alist
                   '(sbt-error-simple
                     "^\\[error\\] -- .*?: \\([^:]+\\):\\([0-9]+\\)" 1 2 nil 2 1))

      (add-to-list 'compilation-error-regexp-alist 'sbt-warning-simple)
      (add-to-list 'compilation-error-regexp-alist-alist
                   '(sbt-warning-simple
                     "^\\[warn\\] -- .*?: \\([^:]+\\):\\([0-9]+\\)" 1 2 nil 1 1)))

    (with-eval-after-load 'evil
      (evil-set-initial-state 'compilation-mode 'normal)
      (evil-define-key 'normal compilation-mode-map
        "n"  'compilation-next-error
        "p"  'compilation-previous-error
        "gn" 'next-error
        "gp" 'previous-error
        "gr" 'recompile
        "q"  'quit-window))
  '';
}
