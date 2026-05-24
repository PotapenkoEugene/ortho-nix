{
  config,
  lib,
  pkgs,
  ...
}:
# orthi-brain: local RAG brain over ~/Orthidian — Mac Studio only.
# Provides:
#   com.ortho.orthi-brain-watch  — file watcher (debounced ingest + reindex)
#   com.ortho.orthi-brain-backup — daily DB snapshot (retain last 7)
#
# Index lives at ~/.local/share/orthi-brain/vault.db (not synced, not in git).
# Code lives at ~/Projects/orthi-brain/ (uv venv, local git).
let
  python = "/Users/ortho/Projects/orthi-brain/.venv/bin/python";
  vaultDir = "/Users/ortho/Orthidian";
  logDir = "/Users/ortho/Library/Logs";
  backupDir = "/Users/ortho/Backups/orthi-brain";
in {
  launchd.agents = {
    orthi-brain-watch = {
      enable = true;
      config = {
        Label = "com.ortho.orthi-brain-watch";
        ProgramArguments = [python "-m" "orthi_brain.watch"];
        WorkingDirectory = "/Users/ortho/Projects/orthi-brain";
        KeepAlive = true;
        RunAtLoad = true;
        StandardOutPath = "${logDir}/orthi-brain-watch.log";
        StandardErrorPath = "${logDir}/orthi-brain-watch.err";
        EnvironmentVariables = {
          HOME = "/Users/ortho";
          PATH = "/Users/ortho/Projects/orthi-brain/.venv/bin:/usr/bin:/bin";
        };
      };
    };

    orthi-brain-backup = {
      enable = true;
      config = {
        Label = "com.ortho.orthi-brain-backup";
        ProgramArguments = [
          "/bin/bash"
          "-c"
          ''
            mkdir -p ${backupDir}
            cp ~/.local/share/orthi-brain/vault.db ${backupDir}/vault-$(date +%Y-%m-%d).db
            ls -t ${backupDir}/vault-*.db | tail -n +8 | xargs rm -f
          ''
        ];
        StartCalendarInterval = [
          {
            Hour = 3;
            Minute = 0;
          }
        ];
        StandardOutPath = "${logDir}/orthi-brain-backup.log";
        StandardErrorPath = "${logDir}/orthi-brain-backup.err";
      };
    };
  };
}
