# Cool prompts with arrows and shit
PROMPT=$'%K{242}[%*]%k%K{238}%F{242}\ue0b0%f %B%~%b %k%F{238}\ue0b0%f '
RPROMPT="%?"

# remove dupes from history
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_FIND_NO_DUPS
setopt HIST_SAVE_NO_DUPS

export EDITOR="code"
alias less="less -R"
alias discordify="magick mogrify -format jpg -resize 1920"

# look for the packages in this file's directory
export ZSH_PACKAGES=""$(dirname ${(%):-%N})""

# long command notification
source "$ZSH_PACKAGES/long_command_notification.zsh"

# syntax highlighting
source "$ZSH_PACKAGES/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

# auto suggestions
source "$ZSH_PACKAGES/zsh-autosuggestions/zsh-autosuggestions.zsh"