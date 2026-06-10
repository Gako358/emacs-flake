_:
{
  order = 1217;
  elisp = ''
    ;;; Web Mode
      (use-package web-mode
        :ensure t
        :mode
        (("\\.phtml\\'" . web-mode)
         ("\\.php\\'" . web-mode)
         ("\\.tpl\\'" . web-mode)
         ("\\.[agj]sp\\'" . web-mode)
         ("\\.as[cp]x\\'" . web-mode)
         ("\\.erb\\'" . web-mode)
         ("\\.mustache\\'" . web-mode)
         ("\\.djhtml\\'" . web-mode)))
  '';
}
