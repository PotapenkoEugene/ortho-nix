# Claude Code settings — assembled with platform guards so settings.json
# is correct on both Linux (full hooks + permissions) and darwin (no notifications/sounds).
{
  pkgs,
  lib,
  config,
}: let
  homeDir = config.home.homeDirectory;
  scriptsDir = "${homeDir}/.config/home-manager/scripts";

  # Linux-only hooks: peon sounds + notify-send
  linuxHooks = {
    SessionStart = [
      {
        matcher = "*";
        hooks = [
          {
            type = "command";
            command = "bash -c '${scriptsDir}/peon-sound.sh session.start &'";
          }
        ];
      }
      {
        matcher = "*";
        hooks = [
          {
            type = "command";
            command = "${scriptsDir}/inject-project-context.sh";
          }
        ];
      }
    ];
    Notification = [
      {
        matcher = "*";
        hooks = [
          {
            type = "command";
            command = "bash -c '${scriptsDir}/claude-notify.sh'";
          }
        ];
      }
    ];
    PostToolUse = [
      {
        matcher = "Bash(home-manager switch)";
        hooks = [
          {
            type = "command";
            command = "bash -c '/usr/bin/notify-send \"Home Manager\" \"Configuration applied successfully!\" -t 5000 -u normal; ${scriptsDir}/peon-sound.sh task.complete &'";
          }
        ];
      }
      {
        matcher = "Bash(home-manager build)";
        hooks = [
          {
            type = "command";
            command = "bash -c '/usr/bin/notify-send \"Home Manager\" \"Build completed successfully\" -t 3000 -u low; ${scriptsDir}/peon-sound.sh task.acknowledge &'";
          }
        ];
      }
    ];
    PostToolUseFailure = [
      {
        matcher = "Bash(home-manager *)";
        hooks = [
          {
            type = "command";
            command = "bash -c '/usr/bin/notify-send \"Home Manager\" \"Build/switch failed! Check errors.\" -t 5000 -u critical; ${scriptsDir}/peon-sound.sh task.error &'";
          }
        ];
      }
    ];
  };

  # darwin: only the cross-platform SessionStart hook (project context injection)
  darwinHooks = {
    SessionStart = [
      {
        matcher = "*";
        hooks = [
          {
            type = "command";
            command = "${scriptsDir}/inject-project-context.sh";
          }
        ];
      }
    ];
  };

  # Bash permissions exclusive to Linux (PipeWire, systemd, GNOME, X11, hardware tools)
  linuxPermissions = [
    "Bash(pkill pw-play *)"
    "Bash(ip *)"
    "Bash(ss *)"
    "Bash(free *)"
    "Bash(pw-play *)"
    "Bash(pw-record *)"
    "Bash(pw-cli *)"
    "Bash(pw-link *)"
    "Bash(pw-dump *)"
    "Bash(pw-loopback *)"
    "Bash(wpctl *)"
    "Bash(pactl *)"
    "Bash(lscpu *)"
    "Bash(lspci *)"
    "Bash(lshw *)"
    "Bash(lsmod *)"
    "Bash(vainfo *)"
    "Bash(clinfo *)"
    "Bash(vulkaninfo *)"
    "Bash(getfacl *)"
    "Bash(findmnt *)"
    "Bash(journalctl *)"
    "Bash(systemctl *)"
    "Bash(dconf *)"
    "Bash(gsettings *)"
    "Bash(gnome-extensions *)"
    "Bash(notify-send *)"
    "Bash(xset *)"
    "Bash(bluetoothctl *)"
    "Bash(xdg-open *)"
  ];
in {
  "$schema" = "https://json.schemastore.org/claude-code-settings.json";
  model = "opusplan";
  effortLevel = "medium";
  showTurnDuration = true;
  includeGitInstructions = false;
  attribution = {
    commit = "Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>";
  };
  statusLine = {
    type = "command";
    command = "${homeDir}/.config/home-manager/claude-code/statusline.sh";
  };
  hooks =
    if pkgs.stdenv.isLinux
    then linuxHooks
    else darwinHooks;
  mcpServers = {
    mcpvault = {
      command = "npx";
      args = ["@bitbonsai/mcpvault@latest" "${homeDir}/Orthidian"];
      env = {};
    };
  };
  permissions = {
    defaultMode = "acceptEdits";
    additionalDirectories = ["~/Orthidian"];
    deny = [
      "Bash(rm -rf /)"
      "Bash(rm -rf /*)"
      "Bash(rm -rf ~)"
      "Bash(rm -rf ~/*)"
      "Bash(git push --force *)"
      "Bash(git push -f *)"
      "Bash(git reset --hard *)"
    ];
    allow =
      [
        "Read"
        "WebSearch"
        "WebFetch"

        "Bash(*)"

        "Bash(grep *)"
        "Bash(awk *)"
        "Bash(sed *)"
        "Bash(cat *)"
        "Bash(head *)"
        "Bash(tail *)"
        "Bash(sort *)"
        "Bash(cut *)"
        "Bash(wc *)"
        "Bash(echo *)"
        "Bash(find *)"
        "Bash(ls *)"
        "Bash(file *)"
        "Bash(tree *)"
        "Bash(xargs *)"
        "Bash(diff *)"
        "Bash(uniq *)"
        "Bash(tr *)"
        "Bash(tee *)"
        "Bash(split *)"
        "Bash(paste *)"
        "Bash(join *)"
        "Bash(comm *)"
        "Bash(column *)"
        "Bash(which *)"
        "Bash(realpath *)"
        "Bash(readlink *)"
        "Bash(dirname *)"
        "Bash(basename *)"
        "Bash(stat *)"
        "Bash(du *)"
        "Bash(df *)"
        "Bash(test *)"
        "Bash([ *)"
        "Bash(date *)"
        "Bash(type *)"
        "Bash(alias *)"
        "Bash(jq *)"
        "Bash(yq *)"
        "Bash(rg *)"
        "Bash(fd *)"
        "Bash(bat *)"
        "Bash(less *)"
        "Bash(hexdump *)"
        "Bash(md5sum *)"
        "Bash(sha256sum *)"
        "Bash(base64 *)"

        "Bash(chmod *)"
        "Bash(mkdir *)"
        "Bash(cp *)"
        "Bash(mv *)"
        "Bash(touch *)"
        "Bash(ln *)"
        "Bash(tar *)"
        "Bash(zip *)"
        "Bash(unzip *)"
        "Bash(gzip *)"
        "Bash(gunzip *)"

        "Bash(pgrep *)"
        "Bash(ps *)"
        "Bash(kill *)"
        "Bash(tty *)"
        "Bash(env *)"
        "Bash(printenv *)"
        "Bash(id *)"
        "Bash(whoami *)"
        "Bash(uname *)"
        "Bash(hostname *)"

        "Bash(python3 *)"
        "Bash(Rscript *)"
        "Bash(R --slave *)"
        "Bash(luajit *)"
        "Bash(bash *)"

        "Bash(alejandra *)"
        "Bash(alejandra . && home-manager build)"
        "Bash(alejandra . && home-manager build && home-manager switch)"
        "Bash(home-manager *)"
        "Bash(nix *)"
        "Bash(nix-env *)"
        "Bash(nix-shell *)"
        "Bash(nix-build *)"
        "Bash(nix-prefetch-url *)"
        "Bash(nix-prefetch-git *)"
        "Bash(nix-prefetch-github *)"
        "Bash(nix-collect-garbage *)"

        "Bash(git *)"

        "Bash(samtools *)"
        "Bash(bcftools *)"
        "Bash(bedtools *)"
        "Bash(bowtie2 *)"
        "Bash(fastqc *)"
        "Bash(multiqc *)"
        "Bash(macs2 *)"
        "Bash(seqkit *)"
        "Bash(minimap2 *)"
        "Bash(micromamba *)"

        "Bash(pandoc *)"
        "Bash(presenterm *)"
        "Bash(inkscape *)"
        "Bash(magick *)"

        "Bash(curl *)"
        "Bash(wget *)"

        "Bash(ffmpeg *)"
        "Bash(ffprobe *)"

        "Bash(whisper *)"
        "Bash(whisper-cli *)"
        "Bash(llama-cli *)"
        "Bash(llama-completion *)"
        "Bash(clean-transcript.sh *)"

        "Bash(docker *)"
        "Bash(docker-compose *)"

        "Bash(tmux *)"

        "Bash(gdalinfo *)"
        "Bash(gdal_translate *)"

        "Bash(gh *)"
        "Bash(tabview *)"
        "Bash(wego *)"
        "Bash(timeout *)"
        "Bash(playwright-cli *)"
        "Bash(notebooklm *)"

        "mcp__mcpvault__search_notes"
        "mcp__mcpvault__get_note"
        "mcp__mcpvault__list_notes"
        "mcp__google-workspace__calendar_listEvents"
        "mcp__google-workspace__calendar_getEvent"
        "mcp__google-workspace__calendar_list"
        "mcp__google-workspace__calendar_findFreeTime"
        "mcp__google-workspace__gmail_search"
        "mcp__google-workspace__gmail_get"
        "mcp__google-workspace__gmail_listLabels"
        "mcp__google-workspace__people_getMe"
        "mcp__google-workspace__time_getCurrentDate"
        "mcp__google-workspace__time_getCurrentTime"
        "mcp__google-workspace__time_getTimeZone"
        "mcp__google-workspace__drive_search"
        "mcp__google-workspace__docs_getText"
        "mcp__google-workspace__docs_find"
        "mcp__google-workspace__sheets_getRange"
        "mcp__google-workspace__sheets_getMetadata"
        "mcp__google-workspace__sheets_getText"
      ]
      ++ lib.optionals pkgs.stdenv.isLinux linuxPermissions;
  };
}
