_:
{
  order = 1213;
  elisp = ''
    ;;; Postgres / MySQL
      ;; sql.el / sql-postgres / sql-mysql tweaks
      (use-package sql
        :defer t
        :custom
        ;; Echo each query before its results so result rows are not glued to
        ;; the prompt — see SqlMode wiki note. Must be upper-case ECHO.
        (sql-postgres-options '("--set=ECHO=all" "-P" "pager=off"))
        ;; Pretty MySQL output (table format, no pager so result fits in comint).
        (sql-mysql-options '("--table" "--pager=cat"))
        ;; Named connections used by `sql-connect' (SPC Dc).
        ;; The password is left unset on purpose: sql.el will prompt for it,
        ;; or pick it up from ~/.authinfo (postgres uses ~/.pgpass natively,
        ;; mysql honours ~/.my.cnf if present).
        (sql-connection-alist
         '((postgres-local
            (sql-product 'postgres)
            (sql-server  "localhost")
            (sql-port    5432)
            (sql-user    "postgres")
            (sql-database "postgres"))
           (mysql-local
            (sql-product 'mysql)
            (sql-server  "127.0.0.1")    ; mysql client treats "localhost" as a unix socket
            (sql-port    3306)
            (sql-user    "root")
            (sql-database ""))))
        :config
        ;; Persist comint history per product (psql, mysql, ...).
        (defun my/sql-save-history-hook ()
          (let ((dir (expand-file-name "sql/" user-emacs-directory)))
            (unless (file-directory-p dir) (make-directory dir t))
            (setq-local sql-input-ring-file-name
      		  (expand-file-name (format "%s-history.sql" sql-product) dir))))
        (add-hook 'sql-interactive-mode-hook 'my/sql-save-history-hook)

        ;; Convenience wrappers so we don't need to remember the connection name.
        (defun my/sql-connect-postgres-local ()
          "Open a sql-postgres comint REPL against localhost:5432."
          (interactive)
          (sql-connect 'postgres-local))

        (defun my/sql-connect-mysql-local ()
          "Open a sql-mysql comint REPL against 127.0.0.1:3306."
          (interactive)
          (sql-connect 'mysql-local)))

      ;; PGmacs — interactive PostgreSQL browser/editor
      (use-package pgmacs
        :ensure t
        :defer t
        :commands (pgmacs pgmacs-open-string pgmacs-open-uri)
        :init
        (with-eval-after-load 'evil-leader
          (evil-leader/set-key
            ;; PGmacs (Postgres browser/editor over the wire protocol)
            "Do" 'pgmacs                     ; Open: prompted connection form
            "DO" 'pgmacs-open-string         ; Open via URI string
            ;; sql.el comint REPLs
            "Dc" 'sql-connect                ; Pick a named connection (alist below)
            "Dp" 'my/sql-connect-postgres-local  ; Direct: postgres@localhost:5432
            "Dm" 'my/sql-connect-mysql-local     ; Direct: mysql@127.0.0.1:3306
            "DP" 'sql-postgres               ; Plain psql REPL (prompts for everything)
            "DM" 'sql-mysql)))               ; Plain mysql REPL (prompts for everything)
  '';
}
