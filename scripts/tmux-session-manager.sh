#!/bin/bash

# Function: save_sessions
# Description: Saves all of the current tmux sessions, windows, and panes to a file to be later restored
# Parameters:
# Returns:
save_sessions() {
  # Start spinner
  start_spinner_with_message "SAVING ALL SESSIONS"

  # Mark all sessions as inactive
  jq '(.sessions[] | .active) = "0"' "$SESSION_FILE" > "$SESSION_FILE.tmp" && mv "$SESSION_FILE.tmp" "$SESSION_FILE"

  # For each session
  tmux list-sessions -F "#{session_name}:#{session_id}" | while IFS=: read -r session_name session_id; do
    # Set the current session as "active" so we can activate again upon restoring
    session_active=0
    if [ "$session_name" == "$(tmux display-message -p '#{session_name}')" ]; then
        session_active=1;
    fi

    # Get all of the data for this session, including windows and panes
    updated_session_data=$(get_session_data "$session_name" "$session_id" "$session_active")

    # Get the existing session data from the sessions file (if it exists)
    existing_session_data=$(jq --arg session_name "$session_name" '.sessions[] | select(.name == $session_name)' "$SESSION_FILE")

    # If this session exists in the session file
    if [ -n "$existing_session_data" ]; then
      # Update the current session in the sessions file
      jq --arg session_name "$session_name" --argjson new_data "$updated_session_data" '.sessions |= map(if .name == $session_name then $new_data else . end)' "$SESSION_FILE" > "$SESSION_FILE.tmp" && mv "$SESSION_FILE.tmp" "$SESSION_FILE"
    else
      # Otherwise add the new session to the sessions file
      jq --argjson new_data "$updated_session_data" '.sessions += [$new_data]' "$SESSION_FILE" > "$SESSION_FILE.tmp" && mv "$SESSION_FILE.tmp" "$SESSION_FILE"
    fi
  done

  # Pretty-print the new sessions file
  jq '.' "$SESSION_FILE" > "$SESSION_FILE.tmp" && mv "$SESSION_FILE.tmp" "$SESSION_FILE"

  # All done saving
  stop_spinner_with_message "SESSION SAVED"
}

# Function: get_session_data
# Description: Helper method to get all of the data associated with the specified session
# Parameters:
#   $1 - Session name
#   $2 - Session ID
#   $3 - Session active status
# Returns:
get_session_data() {
  session_name=$1
  session_id=$2
  session_active=$3
  # Write out this session
  echo "{"
  echo "\"name\":\"$session_name\","
  echo "\"active\":\"$session_active\","
  echo "\"windows\": ["
  # For each window
  tmux list-windows -t "$session_id" -F "#{window_index}:#{window_name}:#{window_id}:#{window_active}:#{window_zoomed_flag}:#{window_layout}" | while IFS=: read -r window_index window_name window_id window_active window_zoomed_flag window_layout; do
    # If this is not the first window add a comma after the previous item
    if [ "$window_index" != "0" ]; then echo ","; fi
    # Write out this window
    echo "{"
    echo "\"index\":$window_index,"
    echo "\"name\":\"$window_name\","
    echo "\"active\":\"$window_active\","
    echo "\"zoomed\":\"$window_zoomed_flag\","
    echo "\"layout\":\"$window_layout\","
    echo "\"panes\": ["
    tmux list-panes -t "$window_id" -F "#{pane_index}:#{pane_id}:#{pane_active}:#{pane_current_path}:#{pane_pid}" | while IFS=: read -r pane_index pane_id pane_active pane_current_path pane_pid; do
      # If this is not the first pane add a comma after the previous item
      if [ "$pane_index" != "0" ]; then echo ","; fi
      # Get the command line arguments for the process running this pane
      pane_command=$(ps --ppid "$pane_pid" -o args= 2>/dev/null | sed 's/"/\\"/g' | sed 's/\n//') # Escape quotes for JSON
      # Don't include this plugin's command in the saved session
      if [[ "$pane_command" == *"tmux-session-manager"* ]]; then
        pane_command=""
      fi

      # Write out this pane
      echo "{"
      echo "\"index\": $pane_index,"
      echo "\"active\": \"$pane_active\","
      echo "\"path\": \"$pane_current_path\","
      echo "\"command\": \"$pane_command\""
      echo "}"
    done
    # End panes
    echo "]}"
  done
  # End windows
  echo "]}"
}

# Function: restore_sessions
# Description: Restore one/all tmux sessions from the session file
# Parameters:
#   $1 - Session name to restore
# Returns:
restore_sessions() {
  # If this parameter is passed in, only the specified session will be restored, otherwise all sessions will be restored
  restore_session_name=$1
  # If this parameters is passed in the specified session will be restored even if it is already loaded
  force_restore=$2

  active_session_name=""
  active_session_window_index=""
  active_session_pane_index=""

  # Get the current session name
  current_session_name=$(tmux display-message -p '#{session_name}')

  # Get the current window id
  current_window_id=$(tmux display-message -p '#{window_id}')

  # Get the current window id
  current_pane_id=$(tmux display-message -p '#{pane_id}')

  # If session is passed filter the session file to only the specified session (faster)
  if [ -n "$restore_session_name" ]; then
    sessions=$(jq -c --arg restore_session_name "$restore_session_name" '.sessions[] | select(.name == $restore_session_name)' "$SESSION_FILE")
    start_spinner_with_message "RESTORING: $restore_session_name"
  else
    # Otherwise, load all sessions
    sessions=$(jq -c '.sessions[]' "$SESSION_FILE")
    start_spinner_with_message "RESTORING ALL SESSIONS"
  fi

  # For each session
  while IFS= read -r session; do
    session_name=$(jq -r '.name' <<< "$session")
    session_active=$(jq -r '.active' <<< "$session")
    active_window_index=""

    # If the session already exists
    if tmux has-session -t "$session_name" 2>/dev/null; then
      # Only restore the session if the force option is true
      if [ "$force_restore" != "true" ]; then
        tmux switch-client -Z -t "${restore_session_name}"
        stop_spinner_with_message "SESSION ALREADY LOADED"
        continue
      fi
      # If the session is not the current session
      if [ "$session_name" != "$current_session_name" ]; then
        # Kill the session before restoring
        tmux kill-session -t "$session_name"
        # Start a new session with the specified name
        tmux new-session -d -s "$session_name"
      else
        # Can't kill the current session, so we just clear it out
        clear_session_contents "$current_session_name" "$current_window_id" "$current_pane_id"
      fi
    else
      # Session doesn't exist, so start a new session with the specified name
      tmux new-session -d -s "$session_name"
    fi

    # For each window
    windows=$(jq -c '.windows[]' <<< "$session")
    while IFS= read -r window; do
      window_index=$(jq -r '.index' <<< "$window")
      window_name=$(jq -r '.name' <<< "$window")
      window_active=$(jq -r '.active' <<< "$window")
      window_zoomed_flag=$(jq -r '.zoomed' <<< "$window")
      window_layout=$(jq -r '.layout' <<< "$window")
      active_window_pane_index=""

      # Do not create a new window if this is the fist window because tmux creates a starting window with each session
      if [ "$window_index" -gt 0 ]; then
        tmux new-window -d -t "$session_name" -n "$window_name"
      fi

      # Select the newly created window
      tmux select-window -t "$session_name:$window_index"

      # For each pane
      panes=$(jq -c '.panes[]' <<< "$window")
      while IFS= read -r pane; do
        pane_index=$(jq -r '.index' <<< "$pane")
        pane_path=$(jq -r '.path' <<< "$pane")
        pane_active=$(jq -r '.active' <<< "$pane")
        pane_command=$(jq -r '.command' <<< "$pane")

        # Keep track of the active session/window/panel so we can restore focus at the end
        if [[ ("$session_active" == "1" || -n "$restore_session_name") && "$window_active" == "1" && "$pane_active" == "1" ]]; then
          active_session_name=$session_name
          active_session_window_index=$window_index
          active_session_pane_index=$pane_index
        fi
        if [[ "$window_active" == "1" && "$pane_active" == "1" ]]; then
          active_window_index=$window_index
          active_window_pane_index=$pane_index
        fi
        if [[ "$pane_active" == "1" ]]; then
          active_pane_index=$pane_index
        fi

        # Do not create a new pane if this is the fist pane because tmux creates a starting pane with each window
        if [ "$pane_index" -gt 0 ]; then
          tmux split-window -t "${session_name}:${window_index}" -c "$pane_path"
        fi                

        # Restore the original process in its pane
        if [ -n "$pane_command" ]; then
          tmux send-keys -t "$session_name:$window_index.$pane_index" "$pane_command" C-m
        elif [ -n "$pane_path" ]; then
          # If there was no process, at least set the path
          tmux send-keys -t "$session_name:$window_index.$pane_index" "cd \"$pane_path\"" C-m "clear" C-m
        fi
      done <<< "$panes"

      # Restore this window's panel layout
      tmux select-layout -t "$session_name:$window_index" "$window_layout"
      # Restore selection of the active pane
      tmux select-pane -t "$session_name:$window_index.$active_pane_index"
      # Restore which panel was zoomed in this window
      if [[ "$window_zoomed_flag" == "1" && -n "$active_pane_index" ]]; then
        tmux resize-pane -t "$session_name:$window_index.$active_pane_index" -Z
      fi
    done <<< "$windows"

    # Restore selection of the active window
    tmux select-window -t "$session_name:$active_window_index.$active_window_pane_index"

  done <<< "$sessions"

  # Restore focus on the active session/window/panel
  if [ -n "$active_session_name" ]; then
    tmux switch-client -Z -t "${active_session_name}:${active_session_window_index}.${active_session_pane_index}"
  fi

  # Kill the session this command was launched from if restoring all
  if [ "$KILL_LAUNCH_SESSION" == "on" ] && [ -z "$restore_session_name" ]; then
      tmux kill-session -t $current_session_name
  fi

  # All done restoring
  stop_spinner_with_message "SESSION(S) RESTORED"
}

# Function: choose_session
# Description: Display a tmux popup that allows choice of tmux sessions from the session file (instead of live sessions)
# Parameters:
# Returns:
choose_session() {
    # Get the list of Session names only
    sessions=$(jq -r '.sessions | .[].name' "$SESSION_FILE")
    session_list=""
    for session in "${sessions[@]}"; do
      session_list+="$session"
    done
    
    # Reset the chosen session
    tmux set-option -gu @lazy_restore_chosen_session

    # Display choice of session to user and then store that choice in a tmux option
    tmux display-popup -E "echo \"${session_list}\" | fzf | tr -d '\n' | xargs -0 -I {} tmux set-option -g @lazy_restore_chosen_session {}"

    # Convert the tmux option to a shell variable
    lazy_restore_chosen_session=$(tmux show-options -gv @lazy_restore_chosen_session)

    # If the user didn't cancel the chooser
    if [ -n "$lazy_restore_chosen_session" ]; then
      # Restore only that session
      restore_sessions "$lazy_restore_chosen_session" "false"
    fi
}

# Function: update_session
# Description: Saves/updates only the current session
# Parameters:
# Returns:
update_session() {
  # Get the current session name
  session_name=$(tmux display-message -p '#{session_name}')
  # Get the current session id
  current_session_id=$(tmux display-message -p '#{session_id}')
  # Get the updated session data
  updated_session_data=$(get_session_data "$session_name" "$current_session_id" "1")

  # Mark all sessions as inactive
  jq '(.sessions[] | .active) = "0"' "$SESSION_FILE" > "$SESSION_FILE.tmp" && mv "$SESSION_FILE.tmp" "$SESSION_FILE"
  # Get the existing session data from the sessions file (if it exists)
  existing_session_data=$(jq --arg session_name "$session_name" '.sessions[] | select(.name == $session_name)' "$SESSION_FILE")
  
  # If the session exists in the session file, update it
  if [ -n "$existing_session_data" ]; then
    # Update the current session in the session file
    jq --arg session_name "$session_name" --argjson new_data "$updated_session_data" '.sessions |= map(if .name == $session_name then $new_data else . end)' "$SESSION_FILE" > "$SESSION_FILE.tmp" && mv "$SESSION_FILE.tmp" "$SESSION_FILE"
  else
    jq --argjson new_data "$updated_session_data" '.sessions += [$new_data]' "$SESSION_FILE" > "$SESSION_FILE.tmp" && mv "$SESSION_FILE.tmp" "$SESSION_FILE"
  fi

  stop_spinner_with_message "SESSION UPDATED"
}

# Function: revert_session
# Description: Revert the current session to its definition in the session file
# Parameters:
# Returns:
revert_session() {
  # Get the current session name
  session_name=$(tmux display-message -p '#{session_name}')

  # Get the current session id
  current_session_id=$(tmux display-message -p '#{session_id}')

  # Restore only that session
  restore_sessions "$session_name" "true"
}

# Function: delete_session
# Description: Deletes only the current session from the sessions file
# Parameters:
# Returns:
delete_session() {
  # Get the current session name
  session_name=$(tmux display-message -p '#{session_name}')

  # Remove the session with the specified name from the session file
  jq --arg session_name "$session_name" 'del(.sessions[] | select(.name == $session_name))' "$SESSION_FILE" > "$SESSION_FILE.tmp" && mv "$SESSION_FILE.tmp" "$SESSION_FILE"

  # If there is more than 1 session
  if [ "$(tmux list-sessions | wc -l)" -gt 1 ]; then
    # Switch to the previous session
    tmux switch-client -l
  fi

  # Kill the current session
  tmux kill-session -t "$session_name" 2>/dev/null

  stop_spinner_with_message "SESSION DELETED"
}

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

# Function: clear_session_contents
# Description: Helper function to clear all windows/panes of the current session, leaving only one empty window/pane
# Parameters:
#   $1 - Current session name
#   $2 - Current window id
#   $3 - Current pane id
# Returns:
clear_session_contents() {
  current_session_name=$1
  current_window_id=$2
  current_pane_id=$3

  # Loop through all windows in the current session
  tmux list-windows -t "$current_session_name" -F "#{window_name}:#{window_id}" | while IFS=: read -r window_name window_id; do
    if [ "$window_id" != "$current_window_id" ]; then
      tmux kill-window -t "$current_session_name:$window_id"
    fi
  done

  # Loop through all panes in the current window
  tmux list-panes -t "$current_session_name:$current_window_id" -F "#{pane_id}" | while IFS= read -r pane_id; do
    # If this pane is not the current pane
    if [ "$pane_id" != "$current_pane_id" ]; then
      # Kill this pane
      tmux kill-pane -t "$pane_id"
    else
      # This is the last pane, so just kill the running process of the current pane
      pid=$(tmux display-message -p -t "$current_pane_id" "#{pane_pid}")
      kill "$pid" 2>/dev/null
    fi
  done
}

# Function: start_spinner_with_message
# Description: Helper function to start the progress spinner with a message
# Parameters:
#   $1 - Message to display
# Returns:
start_spinner_with_message() {
	$CURRENT_DIR/spinner.sh "$1" &
	export SPINNER_PID=$!
}

# Function: stop_spinner_with_message
# Description: Helper function to stop the progress spinner with a message
# Parameters:
#   $1 - Message to display
# Returns:
stop_spinner_with_message() {
  STOP_MESSAGE=$1
	kill $SPINNER_PID
  tmux display-message -N -d 400 "$STOP_MESSAGE"
}


# Get script directory
CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Check if the session file location option is set, otherwise use default location
SESSION_FILE=$(get_tmux_option @tmux-lazy-restore-session-file "$HOME/.config/tmux-lazy-restore/sessions.json")

# Check if the session file exists, if not create the path and the a file with an empty sessions list
if [ ! -f "$SESSION_FILE" ]; then
  mkdir -p "$(dirname "$SESSION_FILE")"
  echo "{\"sessions\": []}" > $SESSION_FILE
fi

# Check if the kill launch session option is set 
KILL_LAUNCH_SESSION=$(get_tmux_option @tmux-lazy-restore-kill-launch-session "off")

# Main
case "$1" in
    choose)
        choose_session
        ;;
    update)
        update_session
        ;;
    revert)
        revert_session
        ;;
    delete)
        delete_session
        ;;
    save_all)
        save_sessions
        ;;
    restore_all)
        restore_sessions
        ;;
    *)
        echo "Usage: $0 {choose|update|restore_all|save_all}"
        exit 1
        ;;
esac

