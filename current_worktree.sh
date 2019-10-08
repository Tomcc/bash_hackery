#!/bin/bash

#for each worktree
while read in; do echo "$in"; done < `git worktree list --porcelain`

#find if we are in a worktree
