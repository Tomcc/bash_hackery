# Cool prompts with arrows and shit
PROMPT=$'%K{248}[%*]%k%K{252}%F{248}\ue0b0%f %B%~%b %k%F{252}\ue0b0%f '
RPROMPT="%?"

# remove dupes from history
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_FIND_NO_DUPS
setopt HIST_SAVE_NO_DUPS

# various system settings
export EDITOR="code"

alias less="less -R"
alias gsuir="git submodule update --init --recursive"
export HOUDINI_LMINFO_VERBOSE=0

# make ssh stop bothering me about new keys & changed IPs
alias sssh=ssh
alias ssh="ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

# Set up pyenv
echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.zshrc
echo 'command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.zshrc
echo 'eval "$(pyenv init -)"' >> ~/.zshrc

# look for the packages in this file's directory
export ZSH_PACKAGES=""$(dirname ${(%):-%N})""

# Pyenv initialization # TODO should it be a plugin?
if command -v pyenv 1>/dev/null 2>&1; then
  eval "$(pyenv init -)"
fi

# long command notification
source "$ZSH_PACKAGES/long_command_notification.zsh"

# z directory jumping
source "$ZSH_PACKAGES/zsh-z/zsh-z.plugin.zsh"
autoload -U compinit && compinit

# auto suggestions
source "$ZSH_PACKAGES/zsh-autosuggestions/zsh-autosuggestions.zsh"

# syntax highlighting
source "$ZSH_PACKAGES/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"