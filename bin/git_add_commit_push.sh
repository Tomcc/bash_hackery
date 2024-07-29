#!/bin/bash

set -euo pipefail

git add --all

if [ ! -z "$1" ] ; then
    git commit -m "$1" --no-status
else
    git commit --no-status
fi

git push --force-with-lease

