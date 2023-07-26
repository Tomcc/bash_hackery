
setopt -o share_history

# expand zsh history to 10000 entries because histdb doesn't work on windows
HISTFILE="$HOME/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000

# fork off into the shareď zshrc in the same folder
SCRIPT_PATH="$(dirname ${(%):-%N})"
source "$SCRIPT_PATH/shared.zshrc"
