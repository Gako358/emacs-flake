_:
{
  order = 208;
  elisp = ''
    ;;; Orderless
  ;; Space-separated matching components matching in any order.
  (use-package orderless
    ;; Vertico leverages Orderless' flexible matching capabilities, allowing users
    ;; to input multiple patterns separated by spaces, which Orderless then
    ;; matches in any order against the candidates.
    :ensure t
    :custom
    (completion-styles '(orderless basic))
    (completion-category-defaults nil)
    (completion-category-overrides '((file (styles partial-completion)))))
  '';
}
