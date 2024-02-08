#!/bin/bash

# Require a message in $1
if [ -z "$1" ]; then
  echo "Usage: git mergemain.sh <commit message>"
  exit 1
fi

set -euo pipefail

# make sure that there are no outstanding git changes
STASHED=false
if [[ -n $(git status --porcelain) ]]; then
  echo "There are outstanding changes in the working directory. Do you want to stash all? Y/n"
  
  read -r response

  if [[ $response == "Y" ]] || [[ $response == "y" ]] || [[ -z $response ]]; then
    # stash the changes, including new files
    git stash --include-untracked
    STASHED=true
  else
    echo "Please commit or stash your changes before running this script."
    exit 1
  fi

fi

# make sure that the current branch is not the main branch
if [[ $(git rev-parse --abbrev-ref HEAD) == "main" ]]; then
  echo "You are currently on the main branch. Please switch to a different branch before running this script."
  exit 1
fi

# make sure that the main branch is up to date
git fetch origin main

# forcibly reset local main to match origin/main
# we do this to avoid checking out a potentially very old main just to update it
git push . origin/main:main --force

# save the current branch
current_branch=$(git rev-parse --abbrev-ref HEAD)

# switch to the main branch
git switch main

# merge the current branch into main with the message in $1
git merge --no-ff -m "$1" $current_branch 

# push the changes to the remote
git push origin main

# switch back to the original branch
git switch -

# unstash the changes if we stashed them
if [[ $STASHED == true ]]; then
  git stash pop
fi