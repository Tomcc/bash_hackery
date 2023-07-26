
# make ssh stop bothering me about new keys & changed IPs
alias sssh=ssh
alias ssh="ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

# Pyenv initialization # TODO should it be a plugin?
export PYENV_ROOT="$HOME/.pyenv"
command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

# fork off into the shareď zshrc in the same folder
SCRIPT_PATH="${(%):-%N}"
source "$(dirname $SCRIPT_PATH)/shared.zshrc"