#!/bin/bash

# create a temp file
temp_file=$(mktemp)

mv "$temp_file" "$temp_file.diff"

# show all changed files
git diff HEAD &> "$temp_file.diff"

# show untracked files
git ls-files --others --exclude-standard | xargs -n 1 git --no-pager diff /dev/null >> "$temp_file.diff"

code -n "$temp_file.diff"