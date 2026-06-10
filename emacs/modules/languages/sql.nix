_:
{
  order = 1212;
  elisp = ''
    ;;; SQL
      ;; SQL syntax-based indentation
      (use-package sql-indent
        :ensure t
        :hook (sql-mode . sqlind-minor-mode))
  '';
}
