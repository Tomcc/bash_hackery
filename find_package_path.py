#!/usr/bin/env python

import argparse
import os
import toml
from fuzzywuzzy import fuzz

# Parse arguments
# The first argument is optional and is the cargo package name

parser = argparse.ArgumentParser(description='Jump to the root folder of any package in a cargo workspace')
parser.add_argument('package', nargs='?', default='', help='The name of the package to jump to')

args = parser.parse_args()

# Get the cargo workspace root Cargo.toml
# This the Cargo.toml file with the [workspace] tag
def get_workspace_toml():
    current_dir = os.getcwd()
    # recurse up, open every Cargo.toml file and check if it has the [workspace] tag
    while True:

        # Check if the current directory contains a Cargo.toml file
        if os.path.isfile(os.path.join(current_dir, 'Cargo.toml')):
            # Open the Cargo.toml file
            current_toml = os.path.join(current_dir, 'Cargo.toml')
            with open(current_toml) as f:
                # Check if the file contains the [workspace] tag
                if '[workspace]' in f.read():
                    # Return the current toml path
                    return current_toml

        parent = os.path.dirname(current_dir)

        # cross platform way to tell the root: if the parent is the same as the current dir, we're at the root
        if parent == current_dir:
            return None

        # If not, go up one directory
        current_dir = parent


root_toml = get_workspace_toml()

if not root_toml:
    print('No workspace found')
    exit(1)

# if args.package wasn't specified, jump to the root folder
if args.package == '':
    print(os.path.dirname(root_toml), end='')
    exit()

# open the toml file and fetch the members of the workspace
with open(root_toml) as f:
    toml_dict = toml.load(f)
    members = toml_dict['workspace']['members']

    # sort the members by fuzzy similarity to $1
    members.sort(key=lambda x: fuzz.partial_ratio(x, args.package), reverse=True)

    # jump to the first result
    print(os.path.join(os.path.dirname(root_toml), members[0]), end='')