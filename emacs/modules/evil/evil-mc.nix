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
    (setq evil-mc-undo-cursors-on-keyboard-quit nil)

    ;; The default `gr' prefix lives in evil-mc's minor-mode map, which gets
    ;; shadowed when `evil-want-keybinding' is nil + evil-collection is used.
    ;; Re-bind it through evil's own global state maps so it always wins.
    ;; `evil-mc-cursors-map' already contains all the per-cursor commands
    ;; (m, u, s, r, f, l, h, j, k, n, p, N, P, I, A, ...).
    (evil-define-key '(normal visual) 'global
      (kbd "gr") evil-mc-cursors-map)

    ;; Match-based cursors (place a cursor on the next/prev occurrence of the
    ;; word under point or the visual selection, then edit them all at once).
    (evil-define-key '(normal visual) 'global
      (kbd "C-n") 'evil-mc-make-and-goto-next-match
      (kbd "C-p") 'evil-mc-make-and-goto-prev-match
      (kbd "C-t") 'evil-mc-skip-and-goto-next-match))
  '';
}
