_:
{
  order = 501;
  elisp = ''
  ;;; Dtrt Indent
  (use-package dtrt-indent
    :ensure t
    :hook (prog-mode . dtrt-indent-mode)
    :custom
    ;; 0 = silent, 1 = report adjustments, 2-3 = debug
    (dtrt-indent-verbosity 1)
    (dtrt-indent-min-quality 60.0))
  '';
}
