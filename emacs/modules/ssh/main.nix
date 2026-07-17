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
  '';
}
