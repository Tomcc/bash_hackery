#!/bin/bash

# Require a message in $1
if [ -z "$1" ]; then
  echo "Usage: git-acpmain.sh <commit message>"
  exit 1
fi

# add, commit and push all our changes
git_add_commit_push.sh "$1"

# then merge the changes into the main branch with the same message
git-mergemain.sh "$1"