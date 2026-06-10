_: {
  order = 1700;
  elisp = ''
    (use-package tramp
      :ensure t
      :defer t
      :config
      (add-to-list 'tramp-remote-path 'tramp-own-remote-path))
  '';
}
