
# look for the packages in this file's directory
export ZSH_PACKAGES=""$(dirname ${(%):-%N})""

# add all the binaries to the path
export MY_BINS="$ZSH_PACKAGES/bin"
export PATH="$MY_BINS:$PATH"

# remove dupes from history
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_FIND_NO_DUPS
setopt HIST_SAVE_NO_DUPS

# various system settings
export EDITOR="code"
export HOUDINI_LMINFO_VERBOSE=0
export DIRENV_LOG_FORMAT=
export AUTO_NOTIFY_THRESHOLD=30

alias less="less -R"

# go to the root of any git repo
alias gcd='cd $(git rev-parse --show-toplevel)'

# watch a directory and run tests with cargo nextest
alias watch_test='cargo watch -- cargo nextest run'

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

eval "$(direnv hook zsh)"

# ---------------- antigen ----------------

# long command notification
# TODO only use this on Windows where zsh-auto-notify doesn't work
# source "$MY_BINS/long_command_notification.zsh"

source /usr/local/share/antigen/antigen.zsh

antigen use oh-my-zsh

antigen bundle zsh-users/zsh-syntax-highlighting
antigen bundle command-not-found
antigen bundle zsh-users/zsh-autosuggestions
antigen bundle command-not-found
antigen bundle thefuck
antigen bundle z

# not on windows
if [[ "$OSTYPE" != "msys" ]]; then
    antigen bundle "MichaelAquilina/zsh-auto-notify"
    antigen bundle mattberther/zsh-pyenv
fi

# only on mac
if [[ "$OSTYPE" == "darwin"* ]]; then
    antigen bundle nvm
    zstyle ':omz:plugins:nvm' autoload yes
fi

antigen theme romkatv/powerlevel10k

antigen apply

echo "$ZSH_PACKAGES"

# p10k preferences
source "$ZSH_PACKAGES/p10k.zsh"