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
  };

  # Create directory for processed transcripts
  home.activation.createTranscriptDirs = lib.hm.dag.entryAfter ["writeBoundary"] ''
    mkdir -p "${config.home.homeDirectory}/Orthidian/processed-transcripts"
  '';
}
