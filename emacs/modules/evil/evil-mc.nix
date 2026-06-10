_:
{
  order = 705;
  elisp = ''
  ;;; Evil Multi-Cursor
  (use-package evil-mc
    :ensure t
    :after evil
    :defer 2
    :config
    (global-evil-mc-mode 1)
    (setq evil-mc-one-cursor-show-mode-line-text nil)
    (setq evil-mc-undo-cursors-on-keyboard-quit nil))
  '';
}
