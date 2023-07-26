
# ---------------- aliases ----------------

# make ssh stop bothering me about new keys & changed IPs
alias sssh=ssh
alias ssh="ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

# ---------------- pyenv ----------------

# Pyenv initialization # TODO should it be a plugin?
export PYENV_ROOT="$HOME/.pyenv"
command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"


# ---------------- normal shell extensions ----------------

# THEFUCK
eval $(thefuck --alias smh)

# --------------- sqlite history 

# setup pexp
source $ZSH_PACKAGES/pexp/pexp_setup.sh

# better history database
export ZSH_PACKAGES=""$(dirname ${(%):-%N})""

HISTDB_TABULATE_CMD=(sed -e $'s/\x1f/\t/g')
source $ZSH_PACKAGES/zsh-histdb/sqlite-history.zsh
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

# --------------- include parent zshrc

# fork off into the shareď zshrc in the same folder
SCRIPT_PATH="${(%):-%N}"
source "$(dirname $SCRIPT_PATH)/shared.zshrc"