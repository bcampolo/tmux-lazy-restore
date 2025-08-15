#!/usr/bin/env bash

# Get the directory of the plugin
CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Function: get_tmux_option
# Description: Helper function to get the value of a tmux option if set, otherwise use the default value
# Parameters:
#   $1 - Option name to get
#   $2 - Default value if option is not set
# Returns:
get_tmux_option() {
	local option_name="$1"
	local default_value="$2"
	local option_value=$(tmux show-option -gqv "$option_name")
	if [ -z "$option_value" ]; then
		echo "$default_value"
	else
		echo "$option_value"
	fi
}

# Keybind to choose a single session to restore
choose_key=$(get_tmux_option "@tmux-lazy-restore-choose-key" "f")
tmux bind-key "$choose_key" run-shell "$CURRENT_DIR/scripts/tmux-session-manager.sh choose"

# Keybind to save/update a single session
update_key=$(get_tmux_option "@tmux-lazy-restore-update-key" "u")
tmux bind-key "$update_key" run-shell "$CURRENT_DIR/scripts/tmux-session-manager.sh update"

# Keybind to revert a single session
revert_key=$(get_tmux_option "@tmux-lazy-restore-revert-key" "r")
tmux bind-key "$revert_key" run-shell "$CURRENT_DIR/scripts/tmux-session-manager.sh revert"

# Keybind to delete a single session
delete_key=$(get_tmux_option "@tmux-lazy-restore-delete-key" "X")
tmux bind-key "$delete_key" run-shell "$CURRENT_DIR/scripts/tmux-session-manager.sh delete"

# Keybind to restore all sessions
restore_all_key=$(get_tmux_option "@tmux-lazy-restore-restore-all-key" "C-r")
tmux bind-key "$restore_all_key" run-shell "$CURRENT_DIR/scripts/tmux-session-manager.sh restore_all"

# Keybind to save/update all sessions
save_all_key=$(get_tmux_option "@tmux-lazy-restore-save-all-key" "C-s")
tmux bind-key "$save_all_key" run-shell "$CURRENT_DIR/scripts/tmux-session-manager.sh save_all"

