
setopt -o share_history

# expand zsh history to 10000 entries because histdb doesn't work on windows
HISTFILE="$HOME/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000

# fork off into the shareď zshrc in the same folder
SCRIPT_PATH="$(dirname ${(%):-%N})"
source "$SCRIPT_PATH/shared.zshrc"

# Patch direnv to work on windows
# The issue is that editing PATH will mangle windows paths
# so all paths need to be passed through cygpath

_direnv_hook() {
  local previous_exit_status=$?;
  eval "$(MSYS_NO_PATHCONV=1 "direnv.exe" export bash | sed 's|export PATH=|export _X_DIRENV_PATH=|g')";
  if [ -n "$_X_DIRENV_PATH" ]; then
    _X_DIRENV_PATH=$(cygpath -p "$_X_DIRENV_PATH")
    export "PATH=$_X_DIRENV_PATH"
    unset _X_DIRENV_PATH
  fi
  return $previous_exit_status;
};


if ! [[ "$PROMPT_COMMAND" =~ _direnv_hook ]]; then
  PROMPT_COMMAND="_direnv_hook;$PROMPT_COMMAND"
fi