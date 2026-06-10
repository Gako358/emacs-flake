_:
{
  order = 1901;
  elisp = ''
    ;;; Ediff
    ;; Configure Ediff to use a single frame and split windows horizontally
    (setq ediff-window-setup-function #'ediff-setup-windows-plain
  	ediff-split-window-function #'split-window-horizontally)
  '';
}
