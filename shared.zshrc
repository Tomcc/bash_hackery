
# look for the packages in this file's directory
export ZSH_PACKAGES=""$(dirname ${(%):-%N})""

# add all the binaries to the path
export MY_BINS="$ZSH_PACKAGES/bin"
export PATH="$MY_BINS:$PATH"

# Cool prompts with arrows and stuff
PROMPT=$'%K{248}[%*]%k%K{252}%F{248}\ue0b0%f %B%~%b %k%F{252}\ue0b0%f %?\n  '

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

# go to the root of any git repo
alias gcd='cd $(git rev-parse --show-toplevel)'

# watch a directory and run tests with cargo nextest
alias watch_test='cargo watch --clear -- cargo nextest run'

# go to any package directory with cargo, or the root if invoked with no argument
pgo() {
    TARGET="$(find_package_path.py $1)"

    # check the error state of find_package_path
    if [ $? -eq 0 ]; then
        cd $TARGET
    else
        echo "No workspace found"
    fi
}

# open any package directory with code. Fail if invoked with no argument
pcode() {
    if [ -z "$1" ]; then
        echo "usage: pcode <package name>"
        return 1
    fi

    TARGET="$(find_package_path.py $1)"

    # check the error state of find_package_path
    if [ $? -eq 0 ]; then
        "$EDITOR" "$TARGET"
    else
        echo "No workspace found"
    fi
}

export HOUDINI_LMINFO_VERBOSE=0

# ---------------- normal shell extensions ----------------

# DIRENV
export DIRENV_LOG_FORMAT=
eval "$(direnv hook zsh)"

# ---------------- plugins ----------------

# long command notification
source "$MY_BINS/long_command_notification.zsh"

# z directory jumping
source "$ZSH_PACKAGES/zsh-z/zsh-z.plugin.zsh"
autoload -U compinit && compinit

# auto suggestions
source "$ZSH_PACKAGES/zsh-autosuggestions/zsh-autosuggestions.zsh"

# syntax highlighting
source "$ZSH_PACKAGES/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"