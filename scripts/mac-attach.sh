#!/usr/bin/env bash
#============================================================================
# Mac Attach — autossh transport to a named mac-studio tmux session
#
# Usage: mac-attach.sh <session>
#   (or via alias: macs <session>)
#
# Naming convention: the kitty tab title should be "mac_<session>" so scripts
# can distinguish mac tabs from local tabs. Single-tab usage: open a kitty
# tab, run this script, then rename the tab to mac_<session> via Ctrl+Shift+R.
# One-key bulk restore (mac-tabs.sh) sets the title automatically.
#
# autossh restarts ssh when the link dies. ssh keepalives detect the dead
# link on wake (~45s with ServerAliveInterval 15 / CountMax 3) then exit;
# autossh relaunches and tmux new-session -A -s reattaches. Plain ssh is
# a transparent byte pipe — kitty graphics protocol passes through intact.
#============================================================================
name="${1:?usage: mac-attach.sh SESSION_NAME}"
exec env AUTOSSH_GATETIME=0 autossh -M 0 -t mac-studio "tmux new-session -A -s '$name'"
