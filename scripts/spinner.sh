#!/bin/bash

## This had to be a separate script so that it can be launched as a process and killed with its PID
MESSAGE=$1
SPINNER='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
SPINNER_LENGTH=${#SPINNER}

while true; do
  i=$(( (i+1) %${SPINNER_LENGTH} ))
  tmux display-message "${SPINNER:$i:1} $MESSAGE"
  sleep 0.1
done

