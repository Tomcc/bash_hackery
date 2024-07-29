#!/bin/bash

# Require a message in $1
if [ -z "$1" ]; then
  echo "Usage: git-mergemain.sh <commit message>"
  exit 1
fi

set -euo pipefail

# save the current branch
current_branch=$(git rev-parse --abbrev-ref HEAD)

# cd to the worktree ending in -main, otherwise error
cd $(git worktree list --porcelain | awk '/worktree .*-main/ {print $2}')

# ensure that main is checked out there
git switch main

# pull the latest changes from the remote
git pull origin main

# merge the current branch into main with the message in $1
git merge --no-ff -m "$1" $current_branch 

# push the changes to the remote
git push origin main

# go back to the original worktree
cd -

# reset the current branch to the state of main
git reset --hard origin/main

# push the changes to the remote
git push origin $current_branch
