_:
{
  order = 706;
  elisp = ''
  ;;; Evil Surround
  (use-package evil-surround
    :after evil
    :ensure t
    :defer t
    :commands global-evil-surround-mode
    :custom
    (evil-surround-pairs-alist
     '((?\( . ("(" . ")"))
       (?\[ . ("[" . "]"))
       (?\{ . ("{" . "}"))

       (?\) . ("(" . ")"))
       (?\] . ("[" . "]"))
       (?\} . ("{" . "}"))

       (?< . ("<" . ">"))
       (?> . ("<" . ">"))))
    :hook (after-init . global-evil-surround-mode))
  '';
}
