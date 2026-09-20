_: {
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

    (defconst my/eca-private-routing-prompts
      '(("lead" . "Use the private Anthropic model profile for this entire task.

When spawning normal agents, explicitly override their configured model and variant as follows:
- architect: anthropic/claude-opus-5, high
- reviewer, refactorer: anthropic/claude-opus-5
- backend, frontend, scala, java, security: anthropic/claude-sonnet-4-6
- explorer, researcher, verifier, summary, docs: anthropic/claude-haiku-4-5-20251001

Do not substitute another model if one is unavailable.

Task: ")
        ("designer" . "Use the private Anthropic model profile for this entire task.

When spawning planning agents, explicitly override their configured model and variant as follows:
- architect: anthropic/claude-opus-5, high
- explorer, researcher, verifier: anthropic/claude-haiku-4-5-20251001

Do not substitute another model if one is unavailable.

Task: ")
        ("debug" . "Use the private Anthropic model profile for this entire task.

When spawning researcher or verifier, explicitly override its configured model with anthropic/claude-haiku-4-5-20251001. Do not substitute another model if it is unavailable.

Task: ")
        ("solo" . "Use the private Anthropic model profile for this entire task.

Task: ")
        ("docs" . "Use the private Anthropic profile with anthropic/claude-haiku-4-5-20251001 and no model substitution.

Task: ")
        ("version" . "Use the private Anthropic model profile for this entire task.

When spawning normal agents, explicitly override their configured model and variant as follows:
- researcher: anthropic/claude-haiku-4-5-20251001
- architect: anthropic/claude-opus-5, high

Do not substitute another model if one is unavailable.

Task: ")))

    (defun my/eca--new-agent-chat (agent model variant prompt)
      "Open a new AGENT chat using MODEL, VARIANT, and initial PROMPT."
      (let ((session (eca-session)))
        (unless session
          (user-error "Start ECA for this workspace with SPC e e first"))
        (eca-assert-session-running session)
        (eca-chat--new-chat session)
        (with-current-buffer (eca-chat--get-last-buffer session)
          (setq-local eca-chat-custom-agent agent)
          (setq-local eca-chat-custom-model model)
          (setq-local eca-chat--selected-model nil)
          (setq-local eca-chat--selected-variant variant)
          (when prompt
            (eca-chat--set-prompt prompt)))))

    (defun my/eca-github-lead-chat ()
      "Open a new Lead chat using its configured GitHub model profile."
      (interactive)
      (my/eca--new-agent-chat "lead" nil nil nil))

    (defun my/eca-private-chat (agent)
      "Open a new private Anthropic chat using AGENT."
      (interactive
       (list (completing-read
              "Private agent: "
              (mapcar #'car my/eca-private-routing-prompts)
              nil t nil nil "lead")))
      (if (equal agent "docs")
          (my/eca--new-agent-chat
           "docs"
           "anthropic/claude-haiku-4-5-20251001"
           nil
           (alist-get agent my/eca-private-routing-prompts nil nil #'equal))
        (my/eca--new-agent-chat
         agent
         "anthropic/claude-opus-5"
         (unless (equal agent "solo") "high")
         (alist-get agent my/eca-private-routing-prompts nil nil #'equal))))

    (use-package eca
      :ensure t
      :defer t
      :custom
      (eca-chat-use-side-window t)
      (eca-chat-window-side 'right)
      (eca-chat-window-width 0.4)
      (eca-worktree-mode 'isolated)
      ;; Focus the chat window when it opens
      (eca-chat-focus-on-open t)
      ;; Automatically include repomap context for better code awareness
      (eca-chat-auto-add-repomap t)

      :init
      (with-eval-after-load 'evil-leader
        (evil-leader/set-key
          ;; Session management
          "ee"  'eca                         ; Start ECA session + open chat
          "eg"  'my/eca-github-lead-chat     ; New GitHub Lead chat
          "ep"  'my/eca-private-chat         ; New private Anthropic agent chat
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

      :config
      ;; Load API keys from .env before ECA spawns its subprocess
      (my/load-env-file (expand-file-name "~/Sources/agentx/azure/.env")))
  '';
}
