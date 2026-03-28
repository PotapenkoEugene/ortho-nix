{
  config,
  pkgs,
  lib,
  ...
}: {
  # Claude Code configuration management
  # This module tracks Claude Code settings, skills, and hooks in version control

  home.file = {
    # Claude Code settings with hooks and permissions
    ".claude/settings.json" = {
      source = ../claude-code/settings.json;
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

    ".claude/skills/obsidian-markdown/SKILL.md" = {
      source = ../claude-code/skills/obsidian-markdown/SKILL.md;
    };
  };

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
}
