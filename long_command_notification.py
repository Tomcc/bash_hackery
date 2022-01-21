#!/usr/bin/env python3
import sys
import subprocess


def notify(msg):
    # put the command in a raw string
    command = [
        "osascript",
        "-e",
        f"display notification \"{msg}\" with title \"Command Completed\""
    ]

    subprocess.check_call(command)

    print(msg)


# complain if there are no args
if len(sys.argv) == 1:
    print("Usage: {} <command>".format(sys.argv[0]))
    sys.exit(1)

MIN_NOTIFICATION_DELAY = 60

stats = sys.argv[1]

# stats is a stat list that looks like: "1025 0:00 sleep 1"

# extract minutes and seconds
minutes, seconds = stats.split()[1].split(":")

# extract the command and its args
command = stats.split()[2:]

# convert list to single string
command = " ".join(command)

# sum up the minutes and seconds
seconds = int(minutes) * 60 + int(seconds)

# if it's been long enough, send a notification
if seconds > MIN_NOTIFICATION_DELAY:
    notify("'{}' has been running for {} s".format(command, seconds))
