{
  pkgs,
  lib,
  ...
}: let
  vault-sync = pkgs.writeShellApplication {
    name = "vault-sync";
    runtimeInputs = [pkgs.git pkgs.openssh pkgs.coreutils];
    text = ''
      VAULT="''${ORTHIDIAN_DIR:-$HOME/Orthidian}"
      cd "$VAULT" || { echo "vault-sync: no vault at $VAULT" >&2; exit 1; }

      # Cap each SSH connection attempt at 10 s so retries finish in ~45 s worst-case.
      # Without this the OS TCP-connect timeout (~2 min) makes 3 retries take ~6 min.
      export GIT_SSH_COMMAND="ssh -o ConnectTimeout=10"

      git add -A
      if ! git diff --cached --quiet; then
        git commit -m "auto: $(uname -n) $(date '+%Y-%m-%d %H:%M')" || true
      fi

      n=0
      until [ "$n" -ge 3 ]; do
        if git pull --rebase --autostash && git push; then
          echo "vault-sync: ok" >&2
          exit 0
        fi
        # Abort any mid-flight rebase so the tree is clean for the next attempt.
        # The local commit is preserved — nothing is lost.
        git rebase --abort 2>/dev/null || true
        n=$((n + 1))
        echo "vault-sync: attempt $n failed, retrying in 5s" >&2
        sleep 5
      done
      echo "vault-sync: FAILED after $n attempts — commit saved locally, will retry next sync" >&2
      exit 1
    '';
  };
in {
  # vault-sync CLI available on all platforms (called by /done and manually)
  home.packages = [vault-sync];

  # ── Linux: boot pull + shutdown push via a single oneshot service ──────────
  # RemainAfterExit=true means systemd considers the service "active" after
  # ExecStart finishes, which causes ExecStop to fire on logout/shutdown.
  # After=network-online.target ensures ExecStop runs before the network goes
  # down (systemd tears down in reverse dependency order).
  systemd.user.services.vault-sync = lib.mkIf pkgs.stdenv.isLinux {
    Unit = {
      Description = "Sync Orthidian vault at login and logout";
      After = ["network-online.target"];
      Wants = ["network-online.target"];
    };
    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${vault-sync}/bin/vault-sync";
      ExecStop = "${vault-sync}/bin/vault-sync";
      # Allow enough time for 3 retry attempts (10s SSH timeout × 3 + sleep overhead).
      TimeoutStartSec = 90;
      TimeoutStopSec = 90;
    };
    Install.WantedBy = ["default.target"];
  };

  # ── macOS: login pull via launchd agent ────────────────────────────────────
  # launchd has no reliable per-user shutdown hook, so Mac only pulls on login.
  # Push is handled by /done (vault-sync step at the end of every task wrap-up).
  launchd.agents.vault-sync = lib.mkIf pkgs.stdenv.isDarwin {
    enable = true;
    config = {
      ProgramArguments = ["${vault-sync}/bin/vault-sync"];
      RunAtLoad = true;
    };
  };
}
