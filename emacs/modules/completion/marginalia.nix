_:
{
  order = 207;
  elisp = ''
    ;;; Marginalia
  ;; Annotations for completion candidates.
  (use-package marginalia
    ;; Marginalia allows Embark to offer you preconfigured actions in more contexts.
    ;; In addition to that, Marginalia also enhances Vertico by adding rich
    ;; annotations to the completion candidates displayed in Vertico's interface.
    :ensure t
    :defer t
    :commands (marginalia-mode marginalia-cycle)
    :hook (after-init . marginalia-mode))
  '';
}
