{pkgs, ...}: {
  systemd.user.services.obsidian-backup = {
    Unit.Description = "Auto-commit and push Orthidian vault";
    Service = {
      Type = "oneshot";
      ExecStart = toString (pkgs.writeShellScript "obsidian-backup" ''
        cd ~/Orthidian
        ${pkgs.git}/bin/git add -A
        ${pkgs.git}/bin/git diff --cached --quiet && exit 0
        ${pkgs.git}/bin/git commit -m "auto: $(date +%Y-%m-%d\ %H:%M)"
        ${pkgs.git}/bin/git push
      '');
    };
  };

  systemd.user.timers.obsidian-backup = {
    Unit.Description = "Daily auto-backup for Orthidian vault";
    Timer = {
      OnCalendar = "daily";
      Persistent = true;
    };
    Install.WantedBy = ["timers.target"];
  };
}
