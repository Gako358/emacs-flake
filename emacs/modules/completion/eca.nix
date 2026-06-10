_:
{
  order = 204;
  elisp = ''
    ;;; Eca
  (defun my/load-env-file (file)
    "Load KEY=VALUE pairs from FILE into Emacs's process environment."
    (when (file-readable-p file)
      (with-temp-buffer
  	(insert-file-contents file)
  	(goto-char (point-min))
  	(while (not (eobp))
  	(let ((line (string-trim
  		     (buffer-substring-no-properties
  		      (line-beginning-position)
  		      (line-end-position)))))
  	  (unless (or (string-empty-p line)
  		      (string-prefix-p "#" line))
  	    (when (string-prefix-p "export " line)
  	      (setq line (substring line 7)))
  	    (when (string-match "\\`\\([^=]+\\)=\\(.*\\)\\'" line)
  	      (let ((key (string-trim (match-string 1 line)))
  		    (val (string-trim (match-string 2 line))))
  		(when (and (>= (length val) 2)
  			   (or (and (string-prefix-p "\"" val)
  				    (string-suffix-p "\"" val))
  			       (and (string-prefix-p "'" val)
  				    (string-suffix-p "'" val))))
  		  (setq val (substring val 1 -1)))
  		(setenv key val)))))
  	(forward-line 1)))))

  (use-package eca
    :ensure t
    :custom
    (eca-chat-use-side-window t)
    (eca-chat-window-side 'right)
    (eca-chat-window-width 0.4)
    ;; Focus the chat window when it opens
    (eca-chat-focus-on-open t)
    ;; Automatically include repomap context for better code awareness
    (eca-chat-auto-add-repomap t)

    :config
    ;; Load API keys from .env before ECA spawns its subprocess
    (my/load-env-file (expand-file-name "~/Sources/agentx/azure/.env"))

    (evil-leader/set-key
      ;; Session management
      "ee"  'eca                         ; Start ECA session + open chat
      "es"  'eca-stop                    ; Stop ECA session
      "eR"  'eca-restart                 ; Restart ECA session
      "eS"  'eca-settings               ; Open settings panel (MCP, etc.)
      ;; Chat
      "ew"  'eca-chat-toggle-window      ; Toggle chat window
      "en"  'eca-chat-new                ; Start a new chat
      "ef"  'eca-chat-select             ; Switch between chats
      "er"  'eca-chat-rename             ; Rename current chat
      "ec"  'eca-chat-clear              ; Clear chat messages
      "eK"  'eca-chat-reset              ; Delete chat and start fresh
      ;; Model and agent
      "em"  'eca-chat-select-model       ; Change model
      "ea"  'eca-chat-select-agent       ; Change agent
      "eA"  'eca-chat-cycle-agent        ; Cycle to next agent
      ;; Context
      "e@"  'eca-chat-add-context-to-user-prompt  ; Add file/dir context
      ;; Tool call approval
      "ey"  'eca-chat-tool-call-accept-all          ; Accept all tool calls
      "eY"  'eca-chat-tool-call-accept-all-and-remember ; Accept and remember
      "ej"  'eca-chat-tool-call-reject-next))       ; Reject next tool call
  '';
}
