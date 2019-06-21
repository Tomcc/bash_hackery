#!/bin/bash

log () {
	tput setaf 6 # cyan
	echo "[Rebaser] $1"
	tput setaf 7 # white
}

quit () {
	tput setaf 1 # red
	echo "[Rebaser] $1"
    echo "Aborting rebase"
	tput setaf 7 # white
    exit 1
}

no_rebase_in_progress () {
    # pretty verbose but very fast way to test this that works anywhere in worktrees or subdirs
    (test -d "$(git rev-parse --git-path rebase-merge)" || \
     test -d "$(git rev-parse --git-path rebase-apply)" ) || return 0
    return 1
}

no_rebase_in_progress || quit "There already is a rebase in progress"


if [ -z "$1" ]; then
    if [ -z "$INTEGRATION" ]; then
        log "no INTEGRATION specified, trying to guess based on worktree"
        
        WORKTREE=`current_worktree.py`
        if [ -z "$WORKTREE" ]; then
            log "Not in a worktree, aborting"
            exit 1
        fi
        
        #try to see if the worktree name is a branch
        TARGET_BRANCH=$(basename $WORKTREE)
        if [[ `git ls-remote origin refs/heads/$TARGET_BRANCH $ | wc -l` -eq 0 ]]; then
            #if not try to check if integration/name is a branch
            TARGET_BRANCH="integration/$TARGET_BRANCH"
            if [[ `git ls-remote origin refs/heads/$TARGET_BRANCH $ | wc -l` -eq 0 ]]; then
                log "No branch \"$TARGET_BRANCH\" found on the remote. Defaulting to main"
                TARGET_BRANCH="main"
            fi
        fi
    else
        TARGET_BRANCH="$INTEGRATION"
    fi
else
    TARGET_BRANCH="$1"
fi

log "Starting rebase on on $TARGET_BRANCH"

#tell visual studio to close
log "Closing Visual Studio"
vs_close.sh

git fetch origin $TARGET_BRANCH || quit "Failed to fetch $TARGET_BRANCH"

CHANGED=$(git diff-index --name-only HEAD --)
if [ -n "$CHANGED" ]; then
    log "Stashing changes before rebasing"
    git stash
fi

CURRENT_INTEGRATION="origin/$TARGET_BRANCH"
git rebase -i --autosquash $CURRENT_INTEGRATION  || quit "Failed to rebase"

while [[ ! no_rebase_in_progress ]]; do
    printf "Running git merge tool. Don't solve the conflicts if you want to end the rebase"
    git mergetool
    
    if [[ `git status | grep "Unmerged paths" | wc -l` -eq 1 ]]; then
        printf "There are still merge conflicts! Please resolve them and continue by hand."
        exit 1
    fi
    
    read -p "${TAG}Do you want to continue rebasing? ${END_TAG}" -n 1 -r
    printf    # (optional) move to a new line
    if [[ ! $REPLY =~ ^[Yy]$ ]]
    then
        quit "Stopping the rebase."
    fi
    
    log "Continuing rebase"
    git rebase --con
done

if [ -n "$CHANGED" ]; then
    log "Unstashing changes"
    git stash pop
fi

#now if it exists, push the _base branch too
BRANCH_NAME=`git symbolic-ref --short HEAD`

log "Updating submodules"
git submodule update --init --recursive

log "Updating the project"
make_vs_project.sh

#auto push and build if there are no unstashed or autogenerated branches
CHANGED=$(git diff-index --name-only HEAD --)
if [ -n "$CHANGED" ]; then
    log "There are unstaged changes, not pushing automatically"
else
    log "Pushing to remote"
    git push --force-with-lease
    
    log "The github url to see all current changes is:"
    log "https://github.com/Mojang/Minecraftpe/compare/$TARGET_BRANCH...$BRANCH_NAME"
    
fi

# asynchronously continue building in another window and then open visual studio
a_incredibuild.sh

log "Rebase done!"
