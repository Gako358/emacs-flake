_: {
  order = 1700;
  elisp = ''
    (use-package tramp
      :ensure t
      :defer t
      :custom
      (tramp-verbose 1)
      (tramp-connection-timeout 20)
      (remote-file-name-inhibit-locks t)
      (remote-file-name-inhibit-auto-save-visited t)
      (remote-file-name-inhibit-cache 60)
      :config
      (add-to-list 'tramp-remote-path 'tramp-own-remote-path)
      ;; VC probing on every remote find-file costs several round trips;
      ;; prohibitive on high-latency methods (mugge relay). Magit still
      ;; works when invoked explicitly.
      (setq vc-ignore-dir-regexp
            (format "%s\\|%s" vc-ignore-dir-regexp tramp-file-name-regexp)))

    (defun merrinx/tramp-mugge-path-p (path)
      "Return non-nil when PATH is a mugge-relay TRAMP path."
      (and (stringp path)
           (or (string-prefix-p "/mugge:" path)
               (string-prefix-p "/mugge-test:" path))))

    (with-eval-after-load 'recentf
      (add-to-list 'recentf-exclude #'merrinx/tramp-mugge-path-p)
      ;; recentf-cleanup (runs when the mode turns on) stats every entry;
      ;; keep remote ones verbatim so cleanup can't dial out.
      (add-to-list 'recentf-keep #'file-remote-p))

    (with-eval-after-load 'saveplace
      ;; Defaults to t, which stats every saved place when the list is
      ;; written (i.e. on exit) — a remote entry reconnects there too.
      (setq save-place-forget-unreadable-files nil)
      (setq save-place-ignore-files-regexp
            (concat "\\`/mugge\\(-test\\)?:\\|" save-place-ignore-files-regexp)))

    (with-eval-after-load 'projectile
      ;; Never track mugge-relay directories as known projects, so
      ;; cleanup/verify never probes them.
      (setq projectile-ignored-project-function #'merrinx/tramp-mugge-path-p))
  '';
}
