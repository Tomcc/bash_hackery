#!/bin/bash

if [ $# -ne 2 ]; then
    echo "Usage: make_worktree branch folder"
    exit 1
fi

git worktree add -B "$1" "../$2" "origin/$1" -f

if [ $? -ne 0 ]; then
    echo "Error while creating the worktree, exiting"
    exit 1
fi

cd "../$2"

git submodule update --init --recursive

restore_nuget.sh

echo "Created worktree in ../$2"