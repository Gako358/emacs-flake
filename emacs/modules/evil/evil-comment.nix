_:
{
  order = 703;
  elisp = ''
  ;;; Evil Comment
  (with-eval-after-load "evil"
    (evil-define-operator my-evil-comment-or-uncomment (beg end)
      "Toggle comment for the region between BEG and END."
      (interactive "<r>")
      (comment-or-uncomment-region beg end))
    (evil-define-key 'normal 'global (kbd "gc") 'my-evil-comment-or-uncomment))
  '';
}
