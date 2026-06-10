_:
{
  order = 1501;
  elisp = ''
    ;;; Org-Modern
    (use-package org-modern
      :ensure t
      :hook ((org-mode . org-modern-mode)
  	   (org-agenda-finalize . org-modern-agenda)))
  '';
}
