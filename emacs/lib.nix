{
  pkgs,
  bivrost,
  muggeSrc,
}:
let
  inherit (pkgs) lib;

  emacsBase = pkgs.emacs31;

  ##########################################################################
  # Custom / overridden packages
  ##########################################################################

  metalsVersion = "2.0.0-M17";
  metalsJavaOpts = "-XX:+UseG1GC -XX:+UseStringDeduplication -Xss4m -Xms100m";

  metalsDeps = pkgs.stdenv.mkDerivation {
    name = "metals-deps-${metalsVersion}";
    buildCommand = ''
      export COURSIER_CACHE=$(pwd)
      ${pkgs.coursier}/bin/cs fetch org.scalameta:metals_2.13:${metalsVersion} > deps
      mkdir -p $out/share/java
      cp $(< deps) $out/share/java/
    '';
    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
    outputHash = "sha256-LGxOm8XX6ZZvPDGiyZAJbGNbwDN/PTuhJGW38JIW1Gg=";
  };

  metals = pkgs.metals.overrideAttrs (
    _final: prev: {
      version = metalsVersion;
      passthru = prev.passthru // {
        deps = metalsDeps;
      };
      buildInputs = [ metalsDeps ];

      nativeBuildInputs = prev.nativeBuildInputs ++ [ pkgs.unzip ];
      installPhase = ''
        mkdir -p $out/bin

        requiredVmOpts=$(unzip -p \
          ${metalsDeps}/share/java/metals_2.13-${metalsVersion}.jar \
          META-INF/metals-required-vm-options.txt | tr '\n' ' ')

        makeWrapper ${pkgs.jre}/bin/java $out/bin/metals \
          --prefix PATH : ${lib.makeBinPath [ pkgs.jre ]} \
          --set JAVA_HOME ${pkgs.jre.home} \
          --add-flags "$requiredVmOpts ${metalsJavaOpts} -cp $CLASSPATH scala.meta.metals.Main"
      '';

      # Upstream's check runs `metals-mcp`, which this pinned build doesn't ship.
      doInstallCheck = false;
    }
  );

  # nixpkgs build-grammar.nix regression: __structuredAttrs hides `language`
  # from jq's env lookup, so monorepo grammars build the wrong parser.
  fixGrammarLanguage =
    grammar:
    grammar.overrideAttrs (_: {
      preConfigure = "export language";
    });

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

  ecaVersion = "0.157.0";

  # Only the amd64 release asset is statically linked; the aarch64 one needs
  # patchelf'ing against glibc/zlib.
  ecaAssets = {
    x86_64-linux = {
      file = "eca-native-static-linux-amd64.zip";
      hash = "sha256-wAjn+g9d3vaIQ6QX7wZ5bCVl668e5nOSVB+i8LXuQFs=";
    };
    aarch64-linux = {
      file = "eca-native-linux-aarch64.zip";
      hash = "sha256-bkOYBP8PQg+guUoi86ZaaQXQXDZ3FvLydVo901+Huas=";
    };
  };

  ecaAsset = ecaAssets.${pkgs.stdenv.hostPlatform.system};

  eca-server = pkgs.stdenv.mkDerivation {
    pname = "eca";
    version = ecaVersion;

    src = pkgs.fetchurl {
      url = "https://github.com/editor-code-assistant/eca/releases/download/${ecaVersion}/${ecaAsset.file}";
      inherit (ecaAsset) hash;
    };

    nativeBuildInputs = [
      pkgs.unzip
      pkgs.autoPatchelfHook
    ];
    buildInputs = [ pkgs.zlib ];

    dontStrip = true;

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
      description = "Editor Code Assistant server (pinned ${ecaVersion})";
      homepage = "https://github.com/editor-code-assistant/eca";
      license = licenses.asl20;
      platforms = attrNames ecaAssets;
      mainProgram = "eca";
    };
  };

  bivrost-theme = emacsBase.pkgs.melpaBuild {
    pname = "bivrost-theme";
    version = "20250330";
    # Source comes from the `bivrost` flake input (see flake.nix); bump it
    # with `nix flake update bivrost` or develop locally via
    # `--override-input bivrost path:/home/merrinx/Projects/bivrost`.
    commit = bivrost.rev or "0000000000000000000000000000000000000000";
    src = bivrost;
    recipe = pkgs.writeText "recipe" ''
      (bivrost-theme
       :repo "gako358/bivrost"
       :fetcher github
       :files ("*.el"))
    '';
  };

  trust-manager = emacsBase.pkgs.melpaBuild {
    pname = "trust-manager";
    version = "0.4.1";
    commit = "530c559ffa01b99ced8073ba4c74f1b8152a0ef2";
    src = pkgs.fetchFromGitHub {
      owner = "eshelyaron";
      repo = "trust-manager";
      rev = "530c559ffa01b99ced8073ba4c74f1b8152a0ef2";
      hash = "sha256-q+QP56TcuATcJ8K72Dzxu6w/Oq/J2wQsIQbBz1gb20A=";
    };
    recipe = pkgs.writeText "recipe" ''
      (trust-manager
       :repo "eshelyaron/trust-manager"
       :fetcher github
       :files ("trust-manager.el"))
    '';
  };

  evil-ghostel-custom = emacsBase.pkgs.melpaBuild {
    pname = "evil-ghostel";
    inherit (emacsBase.pkgs.ghostel) version src;
    packageRequires = with emacsBase.pkgs; [
      evil
      ghostel
    ];
    recipe = pkgs.writeText "recipe" ''
      (evil-ghostel
       :repo "dakra/ghostel"
       :fetcher github
       :files ("extensions/evil-ghostel/evil-ghostel.el"))
    '';
  };

  # Built from source against this Emacs; eat/vterm are soft requires.
  mugge-custom = emacsBase.pkgs.trivialBuild {
    pname = "mugge";
    version = "0.1.0";
    src = muggeSrc;
    packageRequires = [ ];
  };

  hunspellWithDicts = pkgs.hunspell.withDicts (dicts: [
    dicts.en_GB-ise
    dicts.nb_NO
  ]);

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
    pkgs.gh
    pkgs.gh-stack
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
      trust-manager # Convenient per-project trust management
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
          (fixGrammarLanguage tree-sitter-tsx)
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
      dumb-jump # Heuristic jump-to-definition via grep/ripgrep (xref backend)

      # Org
      org # For keeping notes, maintaining TODO lists, and project planning
      org-msg # A msg system used to compose emails for Emacs
      org-modern # A modern org-mode distribution
      org-roam # A note-taking tool based on the principles of networked thought

      # SSH

      # Terminal
      detached # Detached mode for Emacs
      ghostel # Terminal emulator powered by libghostty-vt (vterm replacement)
      evil-ghostel-custom # Evil integration for ghostel (counterpart to evil-collection-vterm)
      mugge-custom # Attach the always-on mugge chat inside Emacs (ghostel backend)

      # Version
      diff-hl # Highlight uncommitted changes in the fringe/margin
      forge # Work with github forges
      magit # A Git porcelain inside Emacs
      pr-review # Review GitHub/GitLab PRs in Emacs
      vundo # Undo tree visualiser
    ];

  ##########################################################################
  # Build-time assembly of the modular configuration.
  #
  # The configuration lives as a tree of small Nix modules under ./modules.
  # Each module is a function returning an attribute set:
  #
  #     { pkgs, lib, ... }:
  #     {
  #       order = <integer>;   # global ordering of the emitted elisp
  #       elisp = ''...'';     # the literal Emacs-Lisp for this unit
  #     }
  #
  # We import every `*.nix` file under ./modules, sort the resulting units by
  # their `order`, and concatenate their `elisp` into a single `config.el`.
  # The result lands in the Nix store (self-contained, no hardcoded paths,
  # no runtime writes to a read-only store). Modules that need store paths
  # (e.g. typescript / vue tooling) interpolate them directly in their elisp.
  ##########################################################################

  orgVersion = "9.8.8";

  emacsPkgSet = (pkgs.emacsPackagesFor emacsBase).overrideScope (
    final: _prev: {
      project = null;
      org = final.elpaBuild {
        pname = "org";
        ename = "org";
        version = orgVersion;
        src = pkgs.fetchurl {
          name = "org-${orgVersion}.tar";
          url = "https://elpa.gnu.org/packages/org-${orgVersion}.tar.lz";
          hash = "sha256-oF8gH3O9mj+SeiF1DJSlregspzEDlNO99f2h2dhwt2Y=";
          postFetch = ''
            ${pkgs.lzip}/bin/lzip -c -d $out > uncompressed
            mv uncompressed $out
          '';
        };
        meta = {
          homepage = "https://elpa.gnu.org/packages/org.html";
          license = lib.licenses.free;
        };
      };
    }
  );

  importModule = f: import f { inherit pkgs lib; };

  # Sort a list of module units by `order` and concatenate their `elisp`,
  # terminating with a `provide` for FEATURE so the result is `require`-able.
  mkConfigElText =
    {
      modules,
      feature,
      header ? "",
    }:
    header
    + lib.concatStringsSep "\n\n" (map (m: m.elisp) (lib.sort (a: b: a.order < b.order) modules))
    + "\n\n(provide '${feature})\n";

  configModules =
    let
      files = lib.filesystem.listFilesRecursive ./modules;
      nixFiles = builtins.filter (f: lib.hasSuffix ".nix" (toString f)) files;
    in
    map importModule nixFiles;

  configElText = mkConfigElText {
    modules = configModules;
    feature = "merrinx-config";
  };

  configEl = pkgs.writeText "merrinx-config.el" configElText;

  configPackage = emacsPkgSet.trivialBuild {
    pname = "merrinx-config";
    version = "1";
    src = pkgs.runCommand "merrinx-config-src" { } ''
      mkdir -p "$out"
      cp ${configEl} "$out/merrinx-config.el"
    '';
    packageRequires = emacsPackagesFn emacsPkgSet;
  };

  ##########################################################################
  # The elisp loaded via programs.emacs.extraConfig (i.e. default.el).
  # Pulls in the native-compiled modular configuration via `require`.
  # Store-path-dependent settings (e.g. typescript / vue tooling) are
  # emitted directly by the relevant modules.
  ##########################################################################

  extraConfig = ''
    (require 'merrinx-config)
  '';

  ##########################################################################
  # A fully configured Emacs package.
  #
  # This bundles the package set together with the configuration so the
  # resulting binary behaves like the one home-manager produces — handy for
  # `nix build` / `nix run` / dev shells.
  #
  # The emacs wrapper exposes every package's site-lisp on the load path, and
  # Emacs auto-loads a `default.el` found there at startup. We therefore ship
  # the startup snippet (`extraConfig`) as its own tiny native-compiled
  # package: it pulls in the compiled configuration via `(require 'merrinx-config)`.
  # (This package is *not* part of the home-manager package set — there,
  # home-manager writes the `default.el` itself from `programs.emacs.extraConfig`.)
  ##########################################################################

  emacsPackagesWithConfig = epkgs: (emacsPackagesFn epkgs) ++ [ configPackage ];

  configBootstrap = emacsPkgSet.trivialBuild {
    pname = "merrinx-config-bootstrap";
    version = "1";
    src = pkgs.runCommand "merrinx-config-bootstrap-src" { } ''
      mkdir -p "$out"
      cat > "$out/default.el" <<'ECA_EOF'
      ${extraConfig}
      ECA_EOF
    '';
    packageRequires = [ configPackage ];
  };

  emacsWithConfig = emacsPkgSet.emacsWithPackages (
    epkgs: (emacsPackagesWithConfig epkgs) ++ [ configBootstrap ]
  );

  ##########################################################################
  # Minimal configuration — a fast, standalone Emacs for quick terminal
  # edits (e.g. aliased to `vim`/`vi`).
  #
  # It reuses a curated subset of the same modules: base settings, evil
  # (motions/leader/surround/comment/visualstar + our keybindings), the
  # theme and the modeline ("the bar"). No LSP, completion UI, project,
  # git, terminal, language or org modules — so startup stays snappy.
  ##########################################################################

  minimalModuleFiles = [
    ./modules/early-init/evil-flags.nix
    ./modules/core/main.nix
    ./modules/visual/fonts.nix
    ./modules/visual/themes.nix
    ./modules/visual/modeline.nix
    ./modules/evil/evil-mode.nix
    ./modules/evil/evil-leader.nix
    ./modules/evil/evil-comment.nix
    ./modules/evil/evil-surround.nix
    ./modules/evil/evil-visualstar.nix
    ./modules/evil/keybindings.nix
    ./modules/languages/nix.nix
    ./minimal/treesit.nix
  ];

  minimalPackagesFn =
    epkgs: with epkgs; [
      evil
      evil-leader
      evil-numbers
      evil-surround
      evil-visualstar
      spaceline
      powerline
      s
      bivrost-theme
      nix-ts-mode
      (treesit-grammars.with-grammars (
        grammars: with grammars; [
          tree-sitter-bash
          tree-sitter-c
          tree-sitter-css
          tree-sitter-dockerfile
          tree-sitter-java
          tree-sitter-javascript
          tree-sitter-lua
          tree-sitter-nix
          tree-sitter-python
          tree-sitter-rust
          (fixGrammarLanguage tree-sitter-tsx)
          tree-sitter-typescript
          tree-sitter-yaml
        ]
      ))
    ];

  minimalConfigElText = mkConfigElText {
    modules = map importModule minimalModuleFiles;
    feature = "merrinx-minimal";
    # The core module's startup machinery relies on lexical closures
    # (e.g. capturing the old `file-name-handler-alist`); without this the
    # generated file would be byte-compiled with dynamic binding and error.
    header = "
;; -*- lexical-binding: t; -*-

";
  };

  minimalConfigEl = pkgs.writeText "merrinx-minimal.el" minimalConfigElText;

  minimalConfigPackage = emacsPkgSet.trivialBuild {
    pname = "merrinx-minimal";
    version = "1";
    src = pkgs.runCommand "merrinx-minimal-src" { } ''
      mkdir -p "$out"
      cp ${minimalConfigEl} "$out/merrinx-minimal.el"
    '';
    packageRequires = minimalPackagesFn emacsPkgSet;
  };

  minimalBootstrap = emacsPkgSet.trivialBuild {
    pname = "merrinx-minimal-bootstrap";
    version = "1";
    src = pkgs.runCommand "merrinx-minimal-bootstrap-src" { } ''
      mkdir -p "$out"
      cat > "$out/default.el" <<'ECA_EOF'
      (require 'merrinx-minimal)
      ECA_EOF
    '';
    packageRequires = [ minimalConfigPackage ];
  };

  emacsMinimal = emacsPkgSet.emacsWithPackages (
    epkgs:
    (minimalPackagesFn epkgs)
    ++ [
      minimalConfigPackage
      minimalBootstrap
    ]
  );
in
{
  inherit
    emacsBase
    emacsPackagesFn
    emacsPackagesWithConfig
    emacsOnlyTools
    emacsOnlyPath
    extraConfig
    configEl
    configPackage
    emacsWithConfig
    minimalConfigEl
    emacsMinimal
    ;
}
