_:
{
  order = 200;
  elisp = ''
    ;;; Completion
  ;; Enable indentation and completion with the TAB key.
  (setq tab-always-indent 'complete)

  ;; Cycle with the TAB key if there are only few candidates.
  (setq completion-cycle-threshold 3)
  '';
}
