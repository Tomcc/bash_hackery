#!/bin/bash

git add --all || exit 1

if [ ! -z "$1" ] ; then
    git commit -m "$1" --no-status || exit 1
else
    git commit --no-status || exit 1
fi

git push --force-with-lease || exit 1

