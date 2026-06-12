{
  pkgs,
  lib,
  ...
}: let
  # ── Overnight personal-note generator ─────────────────────────────────────
  # Runs at 05:00 on the Mac (always-on):
  #   1. Fetch calendar events via calendar-events.sh → tempfile (pre-fetch,
  #      avoids double claude -p when headless nvim assembles the note)
  #   2. Fetch email digests via email-digest.sh
  #   3. Run nvim --headless to generate/update today's personal daily note
  #      (lua script reads CALENDAR_DATA_FILE env var instead of re-calling claude)
  #   4. vault-sync push (so Linux Super+n pull sees the new note)
  #
  # PATH note: launchd agents inherit a minimal /usr/bin:/bin PATH — we need
  # ~/.nix-profile/bin for vault-sync, nvim, claude, kitty, gdate, gstat.
  generate-personal-note = pkgs.writeShellApplication {
    name = "generate-personal-note";
    runtimeInputs = with pkgs; [git openssh coreutils];
    text = ''
      VAULT="''${ORTHIDIAN_DIR:-$HOME/Orthidian}"
      SCRIPTS="$HOME/.config/home-manager/scripts"
      LOG="$HOME/Library/Logs/personal-note.log"

      # Ensure log dir exists
      mkdir -p "$(dirname "$LOG")"

      exec >> "$LOG" 2>&1
      echo "=== personal-note $(date '+%Y-%m-%d %H:%M:%S') ==="

      # ── PATH: nix profile bins (launchd has a minimal PATH) ────────────────
      export PATH="$HOME/.nix-profile/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

      # ── 1. Pull latest vault first ─────────────────────────────────────────
      vault-sync 2>&1 | tail -1 || true

      # ── 2. Pre-fetch calendar events into a tempfile ───────────────────────
      # This avoids the nvim→lua→Calendar.fetch()→claude-p double-spawn problem:
      # the lua script checks CALENDAR_DATA_FILE and reads from it instead.
      CALENDAR_TMP=$(mktemp /tmp/personal-note-calendar-XXXXXX.txt)
      trap 'rm -f "$CALENDAR_TMP"' EXIT

      if [ -x "$SCRIPTS/calendar-events.sh" ]; then
        "$SCRIPTS/calendar-events.sh" > "$CALENDAR_TMP" 2>/dev/null || true
        echo "Calendar: $(wc -l < "$CALENDAR_TMP") events fetched"
      fi

      # ── 3. Fetch email digests (writes to ~/Orthidian/mails/) ─────────────
      if [ -x "$SCRIPTS/email-digest.sh" ]; then
        "$SCRIPTS/email-digest.sh" 2>&1 | tail -3 || true
      fi

      # ── 4. Generate/update today's personal daily note headlessly ──────────
      # CALENDAR_DATA_FILE tells obsidian_daily_notes.lua to consume the
      # pre-fetched data instead of re-calling calendar-events.sh.
      cd "$VAULT" || exit 1
      CALENDAR_DATA_FILE="$CALENDAR_TMP" \
        nvim --headless --noplugin \
          -c "luafile $SCRIPTS/obsidian_daily_notes.lua" \
          -c 'qa!' 2>&1 | head -5 || true
      echo "Note generated: $VAULT/daily/$(date +%Y-%m-%d).md"

      # ── 5. Push vault (so other machines see the note) ─────────────────────
      vault-sync 2>&1 | tail -1 || true

      # ── 6. macOS notification ───────────────────────────────────────────────
      osascript -e 'display notification "Personal note ready" with title "Orthidian"' 2>/dev/null || true

      echo "=== done ==="
    '';
  };
in {
  # ── Package available on all platforms (called directly if needed) ──────────
  home.packages = [generate-personal-note];

  # ── macOS: scheduled overnight launchd agent ───────────────────────────────
  # Uses launchd.agents (home-manager pattern), not launchd.user.agents
  # (nix-darwin system pattern). Pattern mirrors vault-sync.nix.
  launchd.agents.personal-note = lib.mkIf pkgs.stdenv.isDarwin {
    enable = true;
    config = {
      ProgramArguments = ["${generate-personal-note}/bin/generate-personal-note"];
      # Run at 05:00 every day
      StartCalendarInterval = [
        {
          Hour = 5;
          Minute = 0;
        }
      ];
      StandardOutPath = "/Users/ortho/Library/Logs/personal-note.log";
      StandardErrorPath = "/Users/ortho/Library/Logs/personal-note.log";
    };
  };
}
