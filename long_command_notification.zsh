
notify() {
  emulate -L zsh  # Reset shell options inside this function.

  # Fetch the last command with elapsed time from history:
  local -a stats=( "${=$(fc -Dl -1)}" )
  
  "$HOME/dev/bash_hackery/long_command_notification.py" "$stats"

  return 0  # Always return 'true' to avoid any hiccups.
}

# Call the function above before each prompt:
autoload -Uz add-zsh-hook
add-zsh-hook precmd notify
