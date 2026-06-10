_: {
  order = 1207;
  elisp = ''
    (use-package markdown-mode
      :defer t
      :mode (("\\.md\\'" . markdown-mode)
    	   ("\\.markdown\\'" . markdown-mode)))
  '';
}
