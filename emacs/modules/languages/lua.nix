_:
{
  order = 1206;
  elisp = ''
    ;;; Lua
      ;; lua-ts-mode is built-in to Emacs 30+, no external package needed.
      (use-package lua-ts-mode
        :ensure nil
        :mode "\\.lua\\'")
  '';
}
