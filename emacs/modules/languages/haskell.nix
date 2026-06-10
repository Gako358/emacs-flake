_:
{
  order = 1203;
  elisp = ''
    ;;; Haskell
      (use-package haskell-ts-mode
        :ensure t
        :custom
        (haskell-ts-use-indent t)
        (haskell-ts-ghci "ghci")
        :hook (haskell-ts-mode . (lambda ()
      			       (require 'lsp-haskell)))
        :mode (("\\.hs\\'" . haskell-ts-mode)
      	   ("\\.cabal\\'" . haskell-ts-mode)))
  '';
}
