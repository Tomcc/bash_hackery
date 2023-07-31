#!/usr/bin/env python

import os
import sys

if len(sys.argv) < 2:
    print("Usage: build-garbage-collect.py <number of GB>")
    exit(1)

gb = int(sys.argv[1])
bytesize = gb * 1024 * 1024 * 1024

print("Scanning BuildOutput to find the oldest files")

path_modified = list()

for root, dirs, files in os.walk("."):
    for file in files:
        fullpath = os.path.join(root, file)
                
        if "BuildOutput" in fullpath:
            path_modified.append((int(os.path.getmtime(fullpath) / 60), fullpath))


path_modified = sorted(path_modified)

#now try to free enough megabytes
total_size = 0
removed_count = 0
for (timestamp, path) in path_modified:

    removed_count += 1
    size = os.path.getsize(path)

    total_size += size
    
    if total_size > bytesize:
        break

#now actually remove the stuff
for i in range(0, removed_count):
    fullpath = path_modified[i][1]
    os.remove(fullpath)

print("Total freed " + str(total_size / 1024 / 1024) + " mb")