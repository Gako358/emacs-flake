_: {
  order = 1803;
  elisp = ''
    ;;; Mugge chat
    (use-package mugge
      :ensure t
      :commands (mugge
                 mugge-detach
                 mugge-service-status
                 mugge-service-start
                 mugge-service-stop)
      :custom
      (mugge-terminal-backend 'auto)
      :init
      (evil-leader/set-key
        "tm" 'mugge))
  '';
}
