#!/bin/bash
TARGET="$1"
if [ -z "$TARGET" ] 
then
  if [ -z "$INTEGRATION" ]
  then
    INTEGRATION="main"
    echo "No INTEGRATION set, defaulting to main"   
  else
    echo "INTEGRATION set, defaulting to $INTEGRATION"   
  fi

  git fetch origin $INTEGRATION
  TARGET="origin/$INTEGRATION"
fi

BRANCH_NAME=`make_branch_name.sh`

git checkout -b "$BRANCH_NAME" "$TARGET" || exit 1
git push --set-upstream origin "$BRANCH_NAME" || exit 1

git submodule update --init --recursive
restore_nuget.sh