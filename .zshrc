# Add sbin to path
export PATH="/usr/local/sbin:$PATH"

# Cool prompts with arrows and shit
PROMPT=$'%K{242}[%*]%k%K{238}%F{242}\ue0b0%f %B%~%b %k%F{238}\ue0b0%f '
RPROMPT="%?"

export EDITOR="code"
alias less="less -R"
alias discordify="magick mogrify -format jpg -resize 1920"

# DIRENV
export DIRENV_LOG_FORMAT=
eval "$(direnv hook zsh)"

# Secretive Config
export SSH_AUTH_SOCK="/Users/tommaso/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh"

# NVM installation
source $HOME/dev/bash_hackery/nvm_hook.zsh
# long command notification
source $HOME/dev/bash_hackery/long_command_notification.zsh
# syntax highlighting
source /usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
# autocompletion
source /usr/local/share/zsh-autosuggestions/zsh-autosuggestions.zsh