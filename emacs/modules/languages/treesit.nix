_:
{
  order = 902;
  elisp = ''
    ;;; Setting up treesitter grammars
      (use-package treesit
        :ensure nil
        :custom
        (treesit-font-lock-level 4) ;; Set font lock level for Tree-sitter
        :config
        (seq-do (lambda (it)
      	      (push it major-mode-remap-alist))
      	    '((css-mode . css-ts-mode) ;; Remap CSS mode to Tree-sitter mode
      	      (c-mode . c-ts-mode) ;; Remap C mode to Tree-sitter mode
      	      (dockerfile-mode . dockerfile-ts-mode) ;; Remap Dockerfile mode to Tree-sitter mode
      	      (haskell-mode . haskell-ts-mode) ;; Remap Haskell mode to Tree-sitter mode
      	      (java-mode . java-ts-mode) ;; Remap Java mode to Tree-sitter mode
      	      (javascript-mode . js-ts-mode) ;; Remap JavaScript mode to Tree-sitter mode
      	      (kotlin-mode . kotlin-ts-mode) ;; Remap Kotlin mode to Tree-sitter mode
      	      (lua-mode . lua-ts-mode) ;; Remap Lua mode to Tree-sitter mode
      	      (python-mode . python-ts-mode) ;; Remap Python mode to Tree-sitter mode
      	      (scala-mode . scala-ts-mode) ;; Remap Scala mode to Tree-sitter mode
      	      (sh-mode . bash-ts-mode) ;; Remap Shell Script mode to Tree-sitter mode
      	      (shell-script-mode . bash-ts-mode) ;; Remap Shell Script mode to Tree-sitter mode
      	      (typescript-mode . typescript-ts-mode) ;; Remap TypeScript mode to Tree-sitter mode
      	      (yaml-mode . yaml-ts-mode)))) ;; Remap YAML mode to Tree-sitter mode
  '';
}
