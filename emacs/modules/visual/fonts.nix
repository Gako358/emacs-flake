_:
{
  order = 102;
  elisp = ''
    ;;; Fonts
  (add-hook 'after-make-frame-functions
	    (lambda (f)
	      (with-selected-frame f
		(set-frame-font "Iosevka Nerd Font 11" nil t)
		(set-face-attribute 'mode-line nil :font "Iosevka Nerd Font 12" :height 100))))

  (add-to-list 'default-frame-alist '(height . 64))
  (add-to-list 'default-frame-alist '(width . 370))
  '';
}
