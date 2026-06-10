_:
{
  order = 702;
  elisp = ''
  ;;; Evil Collection
  (use-package evil-collection
    :after evil
    :demand t
    :ensure t
    :bind (([remap evil-show-marks] . evil-collection-consult-mark)
  	   ([remap evil-show-jumps] . evil-collection-consult-jump-list))
    :config
    ;; Make `evil-collection-consult-mark' and `evil-collection-consult-jump-list'
    ;; immediately available.
    (evil-collection-require 'consult)
    (evil-collection-init)
    :custom
    (evil-collection-setup-debugger-keys nil)
    (evil-collection-calendar-want-org-bindings t)
    (evil-collection-unimpaired-want-repeat-mode-integration t))
  '';
}
