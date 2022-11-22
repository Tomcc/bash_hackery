# Add sbin to path
export PATH="/usr/local/sbin:$PATH"

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

# DIRENV
export DIRENV_LOG_FORMAT=
eval "$(direnv hook zsh)"

# Secretive Config
export SSH_AUTH_SOCK="/Users/tommaso/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh"

# Aliases
alias hou_dpi_low="unset HOUDINI_UISCALE; echo 'Houdini DPI set to low'"
alias hou_dpi_hi="export HOUDINI_UISCALE=200; echo 'Houdini DPI set to high'"

# NVM installation
source $HOME/dev/bash_hackery/nvm_hook.zsh

# long command notification
source $HOME/dev/bash_hackery/long_command_notification.zsh

# syntax highlighting
source /usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# better history database
HISTDB_TABULATE_CMD=(sed -e $'s/\x1f/\t/g')
source $HOME/dev/bash_hackery/zsh-histdb/sqlite-history.zsh
autoload -Uz add-zsh-hook

# autocompletion, using the database.
# This will find the most frequently issued command issued exactly in this directory, 
# or if there are no matches it will find the most frequently issued command in any directory. 
# You could use other fields like the hostname to restrict to suggestions on this host, etc.

_zsh_autosuggest_strategy_histdb_top() {
    local query="
        select commands.argv from history
        left join commands on history.command_id = commands.rowid
        left join places on history.place_id = places.rowid
        where commands.argv LIKE '$(sql_escape $1)%'
        group by commands.argv, places.dir
        order by places.dir != '$(sql_escape $PWD)', count(*) desc
        limit 1
    "
    suggestion=$(_histdb_query "$query")
}

ZSH_AUTOSUGGEST_STRATEGY=histdb_top

source /usr/local/share/zsh-autosuggestions/zsh-autosuggestions.zsh