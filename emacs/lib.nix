{ pkgs }:
let
  inherit (pkgs) lib;

  # The Emacs we build everything against.
  emacsBase = pkgs.emacs30;

  ##########################################################################
  # Custom / overridden packages
  ##########################################################################

  metalsVersion = "2.0.0-M13";
  metals = pkgs.metals.overrideAttrs (
    final: prev: {
      deps = pkgs.stdenv.mkDerivation {
        name = "${prev.pname}-deps-${metalsVersion}";
        buildCommand = ''
          export COURSIER_CACHE=$(pwd)
          ${pkgs.coursier}/bin/cs fetch org.scalameta:metals_2.13:${metalsVersion} > deps
          mkdir -p $out/share/java
          cp $(< deps) $out/share/java/
        '';
        outputHashMode = "recursive";
        outputHashAlgo = "sha256";
        outputHash = "sha256-Wj/bHosoEugDEwHUZCK2flD8GQVY4MtkFpGKCjI0Zg4=";
      };
      buildInputs = [ final.deps ];
    }
  );

  haskell-ts-mode-custom = emacsBase.pkgs.melpaBuild {
    pname = "haskell-ts-mode";
    version = "1";
    commit = "625b8c5d4c907f822c74c951bfe1bbdd8b187d4e";

    src = pkgs.fetchgit {
      url = "https://codeberg.org/pranshu/haskell-ts-mode.git";
      rev = "625b8c5d4c907f822c74c951bfe1bbdd8b187d4e";
      sha256 = "sha256-G3vKgJAE0kRtwWxsqJGdDOeYpYxUszv0e1fZEiUZuUI=";
    };

    recipe = pkgs.writeText "recipe" ''
      (haskell-ts-mode :fetcher git :url "https://codeberg.org/pranshu/haskell-ts-mode.git")
    '';
  };

  ben-custom = emacsBase.pkgs.melpaBuild {
    pname = "ben";
    version = "0.12.12";
    commit = "c91cce703deb0cafb9f344cbc66d63791665fcb2";

    src = pkgs.fetchgit {
      url = "https://codeberg.org/pastor/ben.el.git";
      rev = "c91cce703deb0cafb9f344cbc66d63791665fcb2";
      sha256 = "sha256-p7KjEYEzBEk4vrUIaeMFezZkOJdhTuWiFt/y5ptOmhY=";
    };

    packageRequires = with emacsBase.pkgs; [ inheritenv ];

    recipe = pkgs.writeText "recipe" ''
      (ben :fetcher git :url "https://codeberg.org/pastor/ben.el.git")
    '';
  };

  pg-el-custom = emacsBase.pkgs.melpaBuild {
    pname = "pg";
    version = "0.65";
    commit = "0eed71bf642c40bac7937a6e8602f41917c90505";
    src = pkgs.fetchFromGitHub {
      owner = "emarsden";
      repo = "pg-el";
      rev = "0eed71bf642c40bac7937a6e8602f41917c90505";
      hash = "sha256-209BJhz1D8g/pJUsc9E+BjlWQAHbeeiT/FhwuO7ytnI=";
    };
    packageRequires = [ emacsBase.pkgs.peg ];
    recipe = pkgs.writeText "recipe" ''
      (pg
       :repo "emarsden/pg-el"
       :fetcher github
       :files ("pg.el" "pg-geometry.el" "pg-gis.el" "pg-bm25.el" "pg-lo.el"))
    '';
  };

  pgmacs-custom = emacsBase.pkgs.melpaBuild {
    pname = "pgmacs";
    version = "0.30";
    commit = "b27999b6b2676514dae6c879e7a72a2beca58a39";
    src = pkgs.fetchFromGitHub {
      owner = "emarsden";
      repo = "pgmacs";
      rev = "b27999b6b2676514dae6c879e7a72a2beca58a39";
      hash = "sha256-cM69R2kz65h8G9hnqDpETD0A/zIbxZ1kK6+gA+V7bhE=";
    };
    packageRequires = [ pg-el-custom ];
    recipe = pkgs.writeText "recipe" ''
      (pgmacs
       :repo "emarsden/pgmacs"
       :fetcher github
       :files ("*.el"))
    '';
  };

  vue-ts-mode = emacsBase.pkgs.melpaBuild {
    pname = "vue-ts-mode";
    version = "20231029";
    commit = "5ec5bb317b80ce394e156c61b7b9c63996382a68";
    src = pkgs.fetchFromGitHub {
      owner = "8uff3r";
      repo = "vue-ts-mode";
      rev = "5ec5bb317b80ce394e156c61b7b9c63996382a68";
      hash = "sha256-1SOlRcq0KSO9n+isUSL5IhlujD4FWcU5I0zP6xuInuQ=";
    };
    recipe = pkgs.writeText "recipe" ''
      (vue-ts-mode
      :repo "8uff3r/vue-ts-mode"
      :fetcher github
      :files ("*.el"))
    '';
  };

  eca-server = pkgs.stdenvNoCC.mkDerivation rec {
    pname = "eca";
    version = "0.140.0";

    src = pkgs.fetchurl {
      url = "https://github.com/editor-code-assistant/eca/releases/download/${version}/eca-native-static-linux-amd64.zip";
      hash = "sha256-6/iH2LW32IivWBrfTEC4waO7QTmuxlpmB7FslHpJjMM=";
    };

    nativeBuildInputs = [ pkgs.unzip ];

    unpackPhase = ''
      runHook preUnpack
      unzip $src
      runHook postUnpack
    '';

    installPhase = ''
      runHook preInstall
      install -Dm755 eca $out/bin/eca
      runHook postInstall
    '';

    meta = with lib; {
      description = "Editor Code Assistant server (pinned ${version})";
      homepage = "https://github.com/editor-code-assistant/eca";
      license = licenses.asl20;
      platforms = [ "x86_64-linux" ];
      mainProgram = "eca";
    };
  };

  bivrost-theme = emacsBase.pkgs.melpaBuild {
    pname = "bivrost-theme";
    version = "20250330";
    commit = "38c6fae362356800b7391fdb4aa999fd76fa1d24";
    src = pkgs.fetchFromGitHub {
      owner = "gako358";
      repo = "bivrost";
      rev = "38c6fae362356800b7391fdb4aa999fd76fa1d24";
      hash = "sha256-bsVoX9G8RfEOAhJHKnCJhYlaCjGA4R75fTPwgN+GGx4=";
    };
    recipe = pkgs.writeText "recipe" ''
      (bivrost-theme
       :repo "gako358/bivrost"
       :fetcher github
       :files ("*.el"))
    '';
  };

  hunspellWithDicts = pkgs.hunspell.withDicts (dicts: [
    dicts.en_GB-ise
    dicts.nb_NO
  ]);

  treesit-predicate-rewrite = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/mwolson/emacs-shared/55d07fa51e28627ff8feb77e5d53cf122eda3c96/init/treesit-predicate-rewrite.el";
    hash = "sha256-2JHHTYVqZcBkldlxqhSZftaZd8jhC+k5Ew3YIKMoJew=";
  };

  ##########################################################################
  # External tools made available on the Emacs PATH
  ##########################################################################

  emacsOnlyTools = [
    eca-server
    hunspellWithDicts
    metals
    pkgs.astyle
    pkgs.black
    pkgs.dtach
    pkgs.gemini-cli
    pkgs.gh
    pkgs.kotlin-language-server
    pkgs.nil
    pkgs.nixfmt
    pkgs.nixfmt-tree
    pkgs.prettier
    pkgs.python313Packages.python-lsp-server
    pkgs.nodejs
    pkgs.postgresql_17
    pkgs.tailwindcss-language-server
    pkgs.typescript
    pkgs.typescript-language-server
    pkgs.vue-language-server
  ];

  emacsOnlyPath = lib.makeBinPath emacsOnlyTools;

  ##########################################################################
  # The Emacs lisp package set
  ##########################################################################

  emacsPackagesFn =
    epkgs: with epkgs; [
      # Appearance
      bivrost-theme # Custom theme
      dashboard # A startup screen extracted from Spacemacs
      indent-bars # Visualise indentation with vertical bars
      spaceline # A mode-line teeming package
      nerd-icons # Nerd icons for Emacs
      nerd-icons-completion # Nerd icons for completion
      nerd-icons-corfu # Nerd icons for corfu
      powerline # A utility library for creating a custom mode-line

      # Completion
      cape # Completion At Point Extensions.
      corfu # Completion Overlay Region Function.
      copilot-chat # Github copilot-chat extension.
      eca # Editor Code Assistant, AI-powered agentic
      embark # Context-sensitive actions.
      embark-consult # Consult preview using embark
      flycheck # On-the-fly syntax checking
      marginalia # Annotations for completion candidates.
      orderless # Space-separated matching components.
      vertico # Vertical interactive completion UI.
      vertico-posframe # Vertigo completion UI with posframe.

      # Documentation
      pdf-tools # Document viewer

      # Evil
      evil # Extensible vi layer for Emacs
      evil-collection # A set of keybindings for evil-mode
      evil-leader # A set of keybindings for evil-mode
      evil-mc # Multiple cursors for evil-mode
      evil-surround # Surround text objects with punctuation
      evil-visualstar # Start a * or # search from the visual selection
      evil-numbers # Increment and decrement numbers in Emacs

      # Edit
      apheleia # A universal formatted interface
      dtrt-indent # Auto-detect buffer indentation offset/tabs

      # File tree
      dirvish # Directory viewer for Emacs

      # General
      alert # Growl-like notifications (mu4e-alert dep)
      dash # A modern list library for Emacs
      editorconfig # EditorConfig Emacs Plugin
      ben-custom # Asynchronous .envrc/direnv support (fork of envrc)
      f # A modern API for working with files and directories in Emacs
      fringe-helper # Helper functions for fringe bitmaps
      gntp # Growl Notification Transport Protocol (alert dep)
      goto-chg # Goto the point of the most recent edit (evil dep)
      log4e # Logging framework for Emacs
      s # The long lost Emacs string manipulation library
      wgrep # Writable grep buffer.

      # Tree-sitter support - specify only the grammars needed
      (treesit-grammars.with-grammars (
        grammars: with grammars; [
          tree-sitter-bash
          tree-sitter-c
          tree-sitter-css
          tree-sitter-dockerfile
          tree-sitter-haskell
          tree-sitter-java
          tree-sitter-javascript
          tree-sitter-kotlin
          tree-sitter-lua
          tree-sitter-markdown
          tree-sitter-nix
          tree-sitter-python
          tree-sitter-rust
          tree-sitter-scala
          tree-sitter-tsx
          tree-sitter-typescript
          tree-sitter-vue
          tree-sitter-yaml
        ]
      ))

      # Programming language packages.
      haskell-ts-mode-custom # Haskell development environment
      kotlin-ts-mode # Kotlin development environment
      markdown-mode # Major mode for editing Markdown files
      nix-ts-mode # Major mode for editing Nix files
      scala-ts-mode # Scala development environment
      sql-indent # Indentation for SQL files
      web-mode # Major mode for editing web templates
      vue-ts-mode # Major mode for editing Vue3 files
      yaml-pro # Major mode for editing YAML files

      # Database
      peg # PEG parser library (required by pg.el)
      pg-el-custom # Pure-elisp PostgreSQL wire-protocol client
      pgmacs-custom # PostgreSQL browser/editor

      # LSP
      lsp-mode # LSP client
      lsp-ui # UI enhancements for lsp-mode
      lsp-java # Java support (replaces eglot-java)
      lsp-metals # Scala Metals support
      lsp-haskell # Haskell LSP support
      lsp-tailwindcss # Tailwind CSS LSP add-on
      dap-mode # Debug Adapter Protocol client (dap-java now ships with lsp-java; Scala DAP is driven by lsp-metals)
      eldoc-box # Display function signatures at point

      # Mail
      mu4e # Emacs mail client
      mu4e-alert # Emacs notification daemon for mu4e

      # Navigation
      consult # Consulting completing-read
      consult-gh # Search GitHub via gh CLI through consult
      consult-gh-embark # Embark integration for consult-gh
      consult-gh-forge # Forge integration for consult-gh (issue viewer)
      consult-lsp # Consult LSP for diagnostics
      consult-projectile # Consult interface for Projectile
      dumb-jump # Heuristic jump-to-definition via grep/ripgrep (xref backend)

      # Org
      org # For keeping notes, maintaining TODO lists, and project planning
      org-msg # A msg system used to compose emails for Emacs
      org-modern # A modern org-mode distribution
      org-roam # A note-taking tool based on the principles of networked thought

      # Project
      projectile # Project Interaction Library for Emacs

      # SSH
      tramp # Transparently access remote machines

      # Terminal
      detached # Detached mode for Emacs
      vterm # Emacs vterm integration
      vterm-toggle # Toggle vterm

      # Version
      diff-hl # Highlight uncommitted changes in the fringe/margin
      forge # Work with github forges
      magit # A Git porcelain inside Emacs
      pr-review # Review GitHub/GitLab PRs in Emacs
      vundo # Undo tree visualiser
    ];

  ##########################################################################
  # Build-time tangling of config.org -> config.el
  #
  # The literate config lives in config.org. We tangle it at build time so
  # the resulting elisp lands in the Nix store (self-contained, no hardcoded
  # paths, no runtime writes to a read-only store).
  ##########################################################################

  tangledConfig = pkgs.runCommand "merrinx-emacs-config.el" { } ''
    cp ${./config.org} config.org
    ${emacsBase}/bin/emacs --batch -Q \
      --eval "(require 'ob-tangle)" \
      --eval "(org-babel-tangle-file \"config.org\" \"config.el\" \"emacs-lisp\")"
    cp config.el $out
  '';

  ##########################################################################
  # The elisp loaded via programs.emacs.extraConfig (i.e. default.el).
  #
  #   1. treesit predicate rewrite (Emacs bug#79687 workaround) — must run
  #      before any tree-sitter font-lock query is compiled.
  #   2. the tangled literate configuration.
  #   3. a few store-path-dependent settings (typescript / vue tooling).
  ##########################################################################

  extraConfig = ''
    ;; Workaround for Emacs bug#79687 (libtree-sitter >= 0.26 rejects
    ;; the predicate names that Emacs 30.2 emits). Must be loaded
    ;; before any tree-sitter font-lock query is compiled.
    (load "${treesit-predicate-rewrite}" nil t)

    (load "${tangledConfig}" nil t)

    (setq lsp-typescript-tsdk "${pkgs.typescript}/lib/node_modules/typescript/lib")
    (setq lsp-clients-typescript-plugins
          (vector
           (list :name "@vue/typescript-plugin"
                 :location "${pkgs.vue-language-server}/lib/language-tools/packages/typescript-plugin"
                 :languages (vector "vue"))))
  '';

  ##########################################################################
  # A fully configured Emacs package.
  #
  # This bundles the package set together with the configuration as a
  # `default.el` on the load path, so the resulting binary behaves like the
  # one home-manager produces — handy for `nix build`/`nix run`/dev shells.
  ##########################################################################

  emacsWithConfig =
    let
      withPkgs = (pkgs.emacsPackagesFor emacsBase).emacsWithPackages emacsPackagesFn;
    in
    withPkgs.overrideAttrs (old: {
      # Drop a default.el next to the wrapper so the config is always loaded.
      postBuild = (old.postBuild or "") + ''
        siteLisp="$out/share/emacs/site-lisp"
        mkdir -p "$siteLisp"
        cat > "$siteLisp/default.el" <<'ECA_EOF'
        ${extraConfig}
        ECA_EOF
      '';
    });
in
{
  inherit
    emacsBase
    emacsPackagesFn
    emacsOnlyTools
    emacsOnlyPath
    extraConfig
    tangledConfig
    emacsWithConfig
    ;
}
