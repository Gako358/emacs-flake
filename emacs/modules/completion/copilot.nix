_:
{
  order = 203;
  elisp = ''
    ;;; Copilot
  (use-package copilot-chat
    :ensure t
    :after (org markdown-mode)
    :config
    ;; Use org-mode frontend (default, other options: 'markdown, 'shell-maker)
    (setq copilot-chat-frontend 'org)
    ;; Use curl backend
    (setq copilot-chat-backend 'curl)
    ;; Follow the chat output as it streams
    (setq copilot-chat-follow t)

    :bind
    (:map global-map
          ("C-c a c" . copilot-chat-display)
          ("C-c a h" . copilot-chat-hide)
          ("C-c a r" . copilot-chat-reset)
          ("C-c a b" . copilot-chat-add-current-buffer)
          ("C-c a d" . copilot-chat-del-current-buffer)
          ("C-c a l" . copilot-chat-list)
          ("C-c a e" . copilot-chat-explain)
          ("C-c a v" . copilot-chat-review)
          ("C-c a f" . copilot-chat-fix)
          ("C-c a o" . copilot-chat-optimize)
          ("C-c a t" . copilot-chat-test)
          ("C-c a g" . copilot-chat-insert-commit-message)
          ("C-c a m" . copilot-chat-set-model)
          ("C-c a T" . copilot-chat-transient)
  	("C-c a w" . copilot-chat-add-workspace)
          ("C-c C-y" . copilot-chat-yank)
          ("C-c M-y" . copilot-chat-yank-pop)))
  '';
}
