
# ---------------- OS detection ----------------
WINDOWS=0
MACOS=0
LINUX=0
USE_ANTIGEN=0
USE_NVM=0
USE_PEXP=0

# if linux
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    LINUX=1

    USE_ANTIGEN=1
    USE_PEXP=1
elif [[ "$OSTYPE" == "darwin"* ]]; then
    MACOS=1

    USE_ANTIGEN=1
    USE_NVM=1
    USE_PEXP=1
elif [[ "$OSTYPE" == "cygwin" ]]; then
    WINDOWS=1
elif [[ "$OSTYPE" == "msys" ]]; then
    WINDOWS=1
else
    echo "Unknown OS: $OSTYPE"
fi

# ---------------- wsl----------------

if [[ "$WSL_DISTRO_NAME" != "" ]]; then

    # MAKE SURE to disable PATH sharing
    # https://learn.microsoft.com/en-us/windows/wsl/wsl-config#wslconf
    # [interop]
    # appendWindowsPath = false

    # Let's add back paths that are actually safe

    # TODO automatically find the Windows user somehow?
    export PATH="$PATH:$(wslpath "$(wslvar USERPROFILE)")/AppData/Local/Programs/Microsoft VS Code/bin"
fi

# ---------------- antigen setup ----------------

if [[ "$USE_ANTIGEN" == "1" ]]; then
    # Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
    # Initialization code that may require console input (password prompts, [y/n]
    # confirmations, etc.) must go above this block; everything else may go below.
    if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
    source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
    fi
fi

# look for the packages in this file's directory
export ZSH_PACKAGES="$(realpath "$(dirname ${(%):-%N})")"

# add all the binaries to the path
export MY_BINS="$ZSH_PACKAGES/bin"
export PATH="$MY_BINS:$PATH"

# ---------------- history ----------------

# if not using ANTIGEN, set up history by hand
if [[ "$USE_ANTIGEN" == "0" ]]; then
    # append to the history file, don't overwrite it
    setopt -o share_history

    # make the history file bigger
    HISTFILE="$HOME/.zsh_history"
    HISTSIZE=10000
    SAVEHIST=10000
fi

# remove dupes from history
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_FIND_NO_DUPS
setopt HIST_SAVE_NO_DUPS

# ---------------- ssh agent ----------------

# if linux
if [[ "$LINUX" == "1" ]]; then
    # start ssh-agent silently
    eval $(ssh-agent -s) > /dev/null
elif [[ "$MACOS" == "1" ]]; then
    # on mac, use secretive
    export SSH_AUTH_SOCK="/Users/tommaso/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh"
fi

# ---------------- pexp ----------------

if [[ "$USE_PEXP" == "1" ]]; then
    # setup pexp
    source $ZSH_PACKAGES/pexp/pexp_setup.sh
fi

# ---------------- exports ----------------

export EDITOR="code"
export HOUDINI_LMINFO_VERBOSE=0
export DIRENV_LOG_FORMAT=
export AUTO_NOTIFY_THRESHOLD=30

# special macos config
if [[ "$MACOS" == "1" ]]; then
    # Add sbin to path
    export PATH="/usr/local/sbin:$PATH"

    # Speed up cargo
    export CARGO_PROFILE_DEV_SPLIT_DEBUGINFO=unpacked
    export CARGO_PROFILE_TEST_SPLIT_DEBUGINFO=unpacked
fi

# ---------------- aliases ----------------

alias less="less -R"

# go to the root of any git repo
alias gcd='cd $(git rev-parse --show-toplevel)'

# watch a directory and run tests with cargo nextest
alias watch_test='cargo watch --clear -- cargo nextest run'
alias watch_bench='cargo watch --clear -- cargo bench'

# Houdini Aliases
alias hou_dpi_low="pexp HOUDINI_UISCALE 100 && echo 'Houdini DPI set to low'"
alias hou_dpi_hi="pexp HOUDINI_UISCALE 200 && echo 'Houdini DPI set to high'"

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

# windows only functions and aliases
if [[ "$WINDOWS" == "1" ]]; then
    
    # windows replacement for `open`
    function open() {
        start "$(cygpath -w "$1")"
    }
fi

# ---------------- direnv ----------------

eval "$(direnv hook zsh)"

if [[ "$WINDOWS" == "1" ]]; then
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
fi

# ---------------- zoxide ----------------

eval "$(zoxide init --cmd cd zsh)"

# ---------------- atuin config ----------------

export ATUIN_CONFIG_DIR="$ZSH_PACKAGES/atuin_config"

# ---------------- antigen ----------------

# check if we use antigen
if [[ "$USE_ANTIGEN" == "1" ]]; then
    source "$ZSH_PACKAGES/antigen.zsh"

    antigen use oh-my-zsh

    antigen bundle zsh-users/zsh-syntax-highlighting
    antigen bundle command-not-found
    antigen bundle zsh-users/zsh-autosuggestions
    antigen bundle thefuck
    antigen bundle "MichaelAquilina/zsh-auto-notify"
    antigen bundle mattberther/zsh-pyenv
    antigen bundle atuinsh/atuin@main

    # nvm isn't always on
    if [[ "$USE_NVM" == "1" ]]; then
        antigen bundle nvm
        zstyle ':omz:plugins:nvm' autoload yes
    fi

    antigen theme romkatv/powerlevel10k

    antigen apply

    # p10k preferences
    source "$ZSH_PACKAGES/p10k.zsh"
else    
    # atuin
    eval "$(atuin init zsh)"
    
    # long command notification
    source "$MY_BINS/long_command_notification.zsh"
    
    # Cool prompts with arrows and stuff without using p10k
    PROMPT=$'%K{248}[%*]%k%K{252}%F{248}\ue0b0%f %B%~%b %k%F{252}\ue0b0%f %?\n  '

    # auto suggestions
    source "$ZSH_PACKAGES/zsh-autosuggestions/zsh-autosuggestions.zsh"

    # syntax highlighting
    source "$ZSH_PACKAGES/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi