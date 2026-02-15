#!/bin/bash
# Start Home Assistant in a tmux session, or attach to an existing one.

HASS_CMD="hass -c config"
SESSION_NAME="hass"

# Find a tmux pane running hass by checking the full process tree of each pane
find_hass_pane() {
    tmux list-panes -a -F '#{pane_pid} #{session_name} #{window_index}' 2>/dev/null | while read -r pane_pid session window; do
        # Check the full process tree under this pane for hass
        if pstree -p "$pane_pid" 2>/dev/null | grep -q "hass"; then
            echo "$session:$window"
            return
        fi
    done
}

hass_pane=$(find_hass_pane)

if [ -n "$hass_pane" ]; then
    hass_session="${hass_pane%%:*}"
    echo "Found running hass instance in tmux session: $hass_pane"
    if [ -n "$TMUX" ]; then
        # Chain select-window and switch-client in a single tmux invocation
        # so both run in the correct client context
        tmux select-window -t "$hass_pane" \; switch-client -t "=$hass_session"
    else
        # select-window first so attaching lands on the right window
        tmux select-window -t "$hass_pane"
        tmux attach-session -t "=$hass_session"
    fi
    exit 0
fi

# No hass running — check if we're inside tmux
if [ -n "$TMUX" ]; then
    echo "Creating new tmux window for hass..."
    tmux new-window -n hass "$HASS_CMD"
    exit 0
fi

# Not inside tmux — check if any tmux session exists
if tmux has-session 2>/dev/null; then
    echo "Attaching to existing tmux session and starting hass..."
    session=$(tmux list-sessions -F '#{session_name}' | head -n1)
    tmux new-window -t "$session" -n hass "$HASS_CMD"
    tmux attach-session -t "$session"
    exit 0
fi

# No tmux session at all — create one
echo "Creating new tmux session with hass..."
tmux new-session -s "$SESSION_NAME" -n hass "$HASS_CMD"
