{pkgs, ...}: {
  systemd.user.services.kitty-session-save = {
    Unit.Description = "Save kitty tab layout (attached tmux sessions)";
    Service = {
      Type = "oneshot";
      ExecStart = toString (pkgs.writeShellScript "kitty-session-save" ''
        SESSION_FILE="$HOME/.config/kitty/session.conf"
        SESSIONS=$(${pkgs.tmux}/bin/tmux list-clients -F '#{client_created} #{session_name}' 2>/dev/null \
            | sort -n | ${pkgs.gawk}/bin/awk '{print $2}' | ${pkgs.gawk}/bin/awk '!seen[$0]++')
        [ -z "$SESSIONS" ] && exit 0
        mkdir -p "$(dirname "$SESSION_FILE")"
        FIRST=true
        while IFS= read -r name; do
            if [ "$FIRST" = true ]; then
                echo "new_tab $name"
                echo "launch kitty-tab-launch.sh $name"
                FIRST=false
            else
                echo ""
                echo "new_tab $name"
                echo "launch kitty-tab-launch.sh $name"
            fi
        done <<< "$SESSIONS" > "$SESSION_FILE"
      '');
    };
  };

  systemd.user.timers.kitty-session-save = {
    Unit.Description = "Periodically save kitty tab layout";
    Timer = {
      OnCalendar = "*:0/5";
      Persistent = true;
    };
    Install.WantedBy = ["timers.target"];
  };

  # Clear stale coordinator lock/done files from kitty-tab-launch.sh on login
  systemd.user.services.tmux-restore-cleanup = {
    Unit.Description = "Clean stale tmux restore coordinator files";
    Service = {
      Type = "oneshot";
      ExecStart = toString (pkgs.writeShellScript "tmux-restore-cleanup" ''
        rm -rf /tmp/tmux-restore-"$(id -u)".lock /tmp/tmux-restore-"$(id -u)".done
      '');
    };
    Install.WantedBy = ["default.target"];
  };
}
