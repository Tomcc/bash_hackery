#!/bin/bash

REMOTE_BRANCH=`git rev-parse --abbrev-ref --symbolic-full-name @{u}`
BRANCH=`echo ${REMOTE_BRANCH#*/}`

git fetch origin "$BRANCH"

git reset --hard "$REMOTE_BRANCH"


