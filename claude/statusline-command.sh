#!/usr/bin/env bash
# Claude Code custom status line.
# Reads the session JSON from stdin and prints two lines:
#   line 1: model name + git branch + context utilization %
#   line 2: session id (own line so it is NEVER truncated — other Claudes
#           grep for it, so the whole thing must always be visible)
# Fields per https://code.claude.com/docs/en/statusline.md

input=$(cat)

model=$(printf '%s' "$input" | jq -r '.model.display_name // "?"')
session=$(printf '%s' "$input" | jq -r '.session_id // "?"')
# used_percentage is null early in a session and just after /compact.
used=$(printf '%s' "$input" | jq -r '.context_window.used_percentage // empty')
cwd=$(printf '%s' "$input" | jq -r '.workspace.current_dir // .cwd // "."')
branch=$(git -C "$cwd" branch --show-current 2>/dev/null)

# ANSI helpers.
dim=$'\033[2m'
bold=$'\033[1m'
cyan=$'\033[36m'
magenta=$'\033[35m'
reset=$'\033[0m'

# Empty outside a repo or on a detached HEAD; skip the segment then.
if [ -n "$branch" ]; then
  git_seg="  ${magenta}${branch}${reset}"
else
  git_seg=""
fi

# Context %: green under 50, yellow under 80, red beyond. Grey "--" if unknown.
if [ -z "$used" ]; then
  ctx="${dim}ctx --${reset}"
else
  used_int=$(printf '%.0f' "$used")
  if [ "$used_int" -lt 50 ]; then
    color=$'\033[32m'
  elif [ "$used_int" -lt 80 ]; then
    color=$'\033[33m'
  else
    color=$'\033[31m'
  fi
  ctx="${color}ctx ${used_int}%${reset}"
fi

# Each element on its own line so nothing reaches the right edge, where CC
# overlays notifications and truncates with "...".
printf '%s%s%s%s  %s\n' "$bold$cyan" "$model" "$reset" "$git_seg" "$ctx"
printf '%s%s%s\n' "$dim" "$session" "$reset"
