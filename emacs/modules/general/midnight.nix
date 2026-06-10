_: {
  order = 805;
  elisp = ''
    (use-package midnight
      :ensure t
      :defer 2
      :config
      (setq clean-buffer-list-delay-general 36000   ;; ~10h for regular buffers
            clean-buffer-list-delay-special 36000   ;; ~10h for special buffers
            ;; Make every buffer a *candidate*; the never-regexps below
            ;; whitelist what must survive.
            clean-buffer-list-kill-regexps '(".*"))
      (setq clean-buffer-list-kill-never-regexps
    	  '("^\\*scratch\\*$"
    	    "^\\*Messages\\*$"
    	    "^\\*dashboard\\*$"
    	    "^\\*tramp/.*\\*$"
    	    "^ \\*Minibuf-.*\\*$"
    	    "^#.*$"                  ;; ERC channels
    	    "^\\*\\*df\\.\\*\\**$"
    	    "^\\*mu4e-.*\\*$"
    	    "^magit\\(:\\| \\).*"))
      (midnight-delay-set 'midnight-delay "4:30am"))
  '';
}
