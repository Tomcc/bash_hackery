
setopt -o share_history

HISTFILE="$HOME/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000

# fork off into the shareď zshrc in the same folder
SCRIPT_PATH="$(dirname ${(%):-%N})"
source "$SCRIPT_PATH/shared.zshrc"
