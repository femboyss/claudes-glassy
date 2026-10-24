#!/usr/bin/env bash
# claudes-glassy: Task-Manager (Strg+Shift+Esc)
# Mission Center, wenn installiert (grafisch, wie unter Windows), sonst btop im Glas-Kitty.

if command -v missioncenter >/dev/null 2>&1; then
    exec missioncenter
elif command -v btop >/dev/null 2>&1; then
    exec kitty --class glassy-taskmgr --title "Task-Manager" -e btop
else
    exec kitty --class glassy-taskmgr --title "Task-Manager" -e top
fi
