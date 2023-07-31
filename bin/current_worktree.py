#!/usr/bin/env python

import subprocess
import os

output = subprocess.check_output(["git", "worktree", "list", "--porcelain"]).decode("utf-8").splitlines()

cwd = os.getcwd()

paths = list()
for line in output:
	if line.startswith("worktree "):
		path = os.path.abspath(line[len("worktree "):])
		paths.append(path)

paths.sort(key = len, reverse=True)

#now check if any of these is part of the root
for path in paths:
	if path in cwd:
		print(path)
		exit(0)
		
exit(1)