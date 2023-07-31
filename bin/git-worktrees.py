#!/usr/bin/env python

import subprocess
import sys
import os

def shell(args, cwd):
    return subprocess.check_output(args, cwd=cwd).decode("utf-8")

def git(*gitargs):
    args = ["git"]
    for arg in gitargs:
        args.append(arg)
    return shell(args, os.getcwd())

def find_integration(folder):
    # can't make this work...
    return ""
    
    # integration = shell(["bash", "-c", "echo", "$INTEGRATION"], folder)[:-1]

    # if not integration:
    #     return "main"
    # return integration

print() 

output = git("worktree", "list", "--porcelain") 

lines = iter(output.splitlines())
worktrees = zip(lines, lines, lines, lines)

for wt in worktrees:
    folder = wt[0][9:]
    commit = wt[1][5:]
    branch = wt[2][18:]

    short_commit = git("rev-parse", "--short=4", commit)[:-1]

    message = git("log", "-n", "1", "--pretty=format:%s", commit)

    integration = find_integration(folder)

    #try to fetch the remote and see if it exists
    try:
        git("fetch", "origin", branch)
        deleted = ""
    except:
        deleted = " (deleted)"
    
    print(folder + " " + short_commit)
    print("[" + integration + " -> " + branch + deleted + "]")
    print(message)

    print()


