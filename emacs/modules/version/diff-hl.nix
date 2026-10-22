_:
{
  order = 1902;
  elisp = ''
    ;;; Diff-hl
    (use-package diff-hl
      :ensure t
      :hook
      ((prog-mode . turn-on-diff-hl-mode)
       (conf-mode . turn-on-diff-hl-mode)
       (text-mode . turn-on-diff-hl-mode)
       (dired-mode . diff-hl-dired-mode)
       ;; Refresh markers around Magit operations
       (magit-pre-refresh . diff-hl-magit-pre-refresh)
       (magit-post-refresh . diff-hl-magit-post-refresh))
      :custom
      (diff-hl-draw-borders nil)
      :config
      ;; Live diffing without requiring a save
      (diff-hl-flydiff-mode 1)
      ;; In TTY frames, use the left margin instead of the (absent) fringe
      (unless (display-graphic-p)
        (diff-hl-margin-mode 1)))
  '';
}
