{
  config,
  pkgs,
  lib,
  ...
}: let
  # notebooklm-py upstream — SKILL.md pinned to same version as the package
  # https://github.com/teng-lin/notebooklm-py
  notebooklmPySrc = pkgs.fetchFromGitHub {
    owner = "teng-lin";
    repo = "notebooklm-py";
    rev = "v0.3.4";
    hash = "sha256-vrCgOYQngSmsv4rnl6CTNk26DB+BxgplwkVfznVbBZo=";
  };

  # Understand-Anything plugin — LLM-powered codebase knowledge graphs
  # https://github.com/Lum1104/Understand-Anything
  understandAnythingSrc = pkgs.fetchFromGitHub {
    owner = "Lum1104";
    repo = "Understand-Anything";
    rev = "822b20d9bf1d499234ff8584b427028cadff523b";
    hash = "sha256-vLlVn0FDrsQ3Ghme/0UVUCI6G3fGEHTyqIbcPvo1u34=";
  };

  # K-Dense-AI scientific skills — 177 skills, MIT licensed
  # https://github.com/K-Dense-AI/claude-scientific-skills
  scientificSkills = pkgs.fetchFromGitHub {
    owner = "K-Dense-AI";
    repo = "claude-scientific-skills";
    rev = "71add644263a56368f8680d68df504c6674dc1e5";
    sha256 = "0lfv88mgnmmy3l16l3d2r343iq2vhmqgwxjkmzi1g3s1vpz6wcl2";
  };

  # Helper: register one K-Dense-AI skill directory as a recursive symlink
  kdenseSkill = name: {
    ".claude/skills/${name}" = {
      source = "${scientificSkills}/${name}";
      recursive = true;
    };
  };
in {
  # Claude Code configuration management
  # This module tracks Claude Code settings, skills, and hooks in version control

  home.file = lib.mkMerge [
    {
      # Claude Code settings — generated from Nix with platform guards
      # (hooks + permissions differ between Linux and darwin)
      ".claude/settings.json" = {
        text = builtins.toJSON (import ../claude-code/settings.nix {
          inherit pkgs lib config;
        });
      };

      # Global Claude Code instructions (applies to all projects)
      ".claude/CLAUDE.md" = {
        source = ../claude-code/CLAUDE.md;
      };

      # Status line script
      ".claude/statusline.sh" = {
        source = ../claude-code/statusline.sh;
        executable = true;
      };

      # Skills - Custom slash commands
      ".claude/skills/hm-switch/SKILL.md" = {
        source = ../claude-code/skills/hm-switch/SKILL.md;
      };

      ".claude/skills/process-transcript/SKILL.md" = {
        source = ../claude-code/skills/process-transcript/SKILL.md;
      };

      ".claude/skills/note/SKILL.md" = {
        source = ../claude-code/skills/note/SKILL.md;
      };

      ".claude/skills/mail/SKILL.md" = {
        source = ../claude-code/skills/mail/SKILL.md;
      };

      ".claude/skills/peon-ping-config/SKILL.md" = {
        source = ../claude-code/skills/peon-ping-config/SKILL.md;
      };

      ".claude/skills/peon-ping-toggle/SKILL.md" = {
        source = ../claude-code/skills/peon-ping-toggle/SKILL.md;
      };

      ".claude/skills/frontend-design/SKILL.md" = {
        source = ../claude-code/skills/frontend-design/SKILL.md;
      };

      ".claude/skills/ux-design-principles/SKILL.md" = {
        source = ../claude-code/skills/ux-design-principles/SKILL.md;
      };

      ".claude/skills/shiny-bslib" = {
        source = ../claude-code/skills/shiny-bslib;
        recursive = true;
      };

      ".claude/skills/shiny-bslib-theming" = {
        source = ../claude-code/skills/shiny-bslib-theming;
        recursive = true;
      };

      ".claude/skills/worktree/SKILL.md" = {
        source = ../claude-code/skills/worktree/SKILL.md;
      };

      ".claude/skills/commit/SKILL.md" = {
        source = ../claude-code/skills/commit/SKILL.md;
      };

      ".claude/skills/knowledge/SKILL.md" = {
        source = ../claude-code/skills/knowledge/SKILL.md;
      };

      ".claude/skills/done/SKILL.md" = {
        source = ../claude-code/skills/done/SKILL.md;
      };

      ".claude/skills/obsidian-markdown/SKILL.md" = {
        source = ../claude-code/skills/obsidian-markdown/SKILL.md;
      };

      # Custom R tidy code skill
      ".claude/skills/tidy-r" = {
        source = ../claude-code/skills/tidy-r;
        recursive = true;
      };

      # NotebookLM upstream skill — full CLI knowledge from notebooklm-py v0.3.4
      ".claude/skills/notebooklm/SKILL.md" = {
        source = "${notebooklmPySrc}/SKILL.md";
      };

      # Custom /notebook workflow skill — session prep, research synthesis, knowledge base integration
      ".claude/skills/notebook/SKILL.md" = {
        source = ../claude-code/skills/notebook/SKILL.md;
      };

      # Understand-Anything skills — LLM-powered codebase knowledge graphs
      ".claude/skills/understand" = {
        source = "${understandAnythingSrc}/understand-anything-plugin/skills/understand";
        recursive = true;
      };
      ".claude/skills/understand-chat/SKILL.md" = {
        source = "${understandAnythingSrc}/understand-anything-plugin/skills/understand-chat/SKILL.md";
      };
      ".claude/skills/understand-dashboard/SKILL.md" = {
        source = "${understandAnythingSrc}/understand-anything-plugin/skills/understand-dashboard/SKILL.md";
      };
      ".claude/skills/understand-diff/SKILL.md" = {
        source = "${understandAnythingSrc}/understand-anything-plugin/skills/understand-diff/SKILL.md";
      };
      ".claude/skills/understand-domain/SKILL.md" = {
        source = "${understandAnythingSrc}/understand-anything-plugin/skills/understand-domain/SKILL.md";
      };
      ".claude/skills/understand-explain/SKILL.md" = {
        source = "${understandAnythingSrc}/understand-anything-plugin/skills/understand-explain/SKILL.md";
      };
      ".claude/skills/understand-knowledge/SKILL.md" = {
        source = "${understandAnythingSrc}/understand-anything-plugin/skills/understand-knowledge/SKILL.md";
      };
      ".claude/skills/understand-onboard/SKILL.md" = {
        source = "${understandAnythingSrc}/understand-anything-plugin/skills/understand-onboard/SKILL.md";
      };
    }

    # K-Dense-AI scientific skills — core bioinformatics
    (kdenseSkill "scanpy")
    (kdenseSkill "biopython")
    (kdenseSkill "pydeseq2")
    (kdenseSkill "deeptools")
    (kdenseSkill "scikit-bio")
    (kdenseSkill "anndata")

    # K-Dense-AI scientific skills — statistics & ML
    (kdenseSkill "statistical-analysis")
    (kdenseSkill "statsmodels")
    (kdenseSkill "scikit-learn")
    (kdenseSkill "scikit-survival")
    (kdenseSkill "pymc")
    (kdenseSkill "shap")

    # K-Dense-AI scientific skills — databases & search
    (kdenseSkill "gene-database")
    (kdenseSkill "ensembl-database")
    (kdenseSkill "clinvar-database")
    (kdenseSkill "gnomad-database")
    (kdenseSkill "gwas-database")
    (kdenseSkill "pubmed-database")
    (kdenseSkill "kegg-database")
  ];

  # Create directory for processed transcripts
  home.activation.createTranscriptDirs = lib.hm.dag.entryAfter ["writeBoundary"] ''
    mkdir -p "${config.home.homeDirectory}/Orthidian/processed-transcripts"
  '';

  # Install playwright-cli browsers (chromium rev 1212, not in nixpkgs playwright-driver)
  # Idempotent: skipped if chromium-1212 already in cache
  home.activation.installPlaywrightBrowsers = lib.hm.dag.entryAfter ["installPackages"] ''
    if command -v playwright-cli &>/dev/null && \
       [ ! -d "${config.home.homeDirectory}/.cache/ms-playwright/chromium-1212" ]; then
      cd "${config.home.homeDirectory}" && playwright-cli install 2>/dev/null || true
    fi
  '';

  # Install understand-anything plugin into Claude Code's plugin cache.
  # Uses mutable copy (not symlink) so pnpm can write node_modules on first use.
  # The plugin's SKILL.md handles `pnpm build` automatically on first invocation.
  home.activation.installUnderstandAnything = lib.hm.dag.entryAfter ["writeBoundary"] ''
    PLUGIN_CACHE="$HOME/.claude/plugins/cache/understand-anything/understand-anything/2.3.1"
    INSTALLED_JSON="$HOME/.claude/plugins/installed_plugins.json"

    if [ ! -d "$PLUGIN_CACHE" ]; then
      mkdir -p "$(dirname "$PLUGIN_CACHE")"
      cp -r "${understandAnythingSrc}/understand-anything-plugin" "$PLUGIN_CACHE"
      chmod -R u+w "$PLUGIN_CACHE"
    fi

    if [ ! -f "$INSTALLED_JSON" ] || ! ${pkgs.jq}/bin/jq empty "$INSTALLED_JSON" 2>/dev/null; then
      printf '{"version": 2, "plugins": {}}' > "$INSTALLED_JSON"
    fi

    ${pkgs.jq}/bin/jq \
      --arg path "$PLUGIN_CACHE" \
      '.plugins["understand-anything@understand-anything"] //= [
        {
          "scope": "user",
          "installPath": $path,
          "version": "2.3.1",
          "installedAt": "2026-04-22T00:00:00.000Z",
          "lastUpdated": "2026-04-22T00:00:00.000Z",
          "gitCommitSha": "822b20d9bf1d499234ff8584b427028cadff523b"
        }
      ]' "$INSTALLED_JSON" > "$INSTALLED_JSON.tmp" && \
      mv "$INSTALLED_JSON.tmp" "$INSTALLED_JSON"
  '';

  # Install Python playwright's chromium for notebooklm login flow
  # Uses playwright binary from the notebooklm-py closure (rev 1200, separate from playwright-cli's rev 1212)
  # Idempotent: skipped if chromium-1200 already present
  home.activation.installNotebooklmBrowsers = lib.hm.dag.entryAfter ["installPackages"] ''
    NOTEBOOKLM_BIN=$(readlink -f "${config.home.homeDirectory}/.nix-profile/bin/notebooklm" 2>/dev/null || true)
    if [ -n "$NOTEBOOKLM_BIN" ]; then
      PLAYWRIGHT_BIN=$(dirname "$NOTEBOOKLM_BIN" | sed 's|/bin$||' | xargs -I{} find {} -name playwright -path "*/playwright-1*/bin/playwright" 2>/dev/null | head -1)
      if [ -n "$PLAYWRIGHT_BIN" ] && [ ! -d "${config.home.homeDirectory}/.cache/ms-playwright/chromium-1200" ]; then
        PLAYWRIGHT_BROWSERS_PATH="${config.home.homeDirectory}/.cache/ms-playwright" "$PLAYWRIGHT_BIN" install chromium 2>/dev/null || true
      fi
    fi
  '';
}
