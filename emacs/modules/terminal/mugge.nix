_: {
  order = 1803;
  elisp = ''
    ;;; Mugge chat
    (use-package mugge
      :ensure t
      :commands (mugge
                 mugge-toggle
                 mugge-detach
                 mugge-service-status
                 mugge-service-start
                 mugge-service-stop
                 mugge-assist
                 mugge-assist-end)
      :custom
      (mugge-terminal-backend 'auto)
      :init
      (evil-leader/set-key
        "tm" 'mugge-toggle
        "ta" 'mugge-assist
        "tq" 'mugge-assist-end))
  '';
}
