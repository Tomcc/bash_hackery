#!/usr/bin/env python3
import sys
import subprocess


def notify(msg):
    msg = msg.replace("\"", "\\\"")

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

MIN_NOTIFICATION_DELAY = 30

# stats is a stat list that looks like: "1025 0:00 sleep 1"
stats = sys.argv[1].split()
time = stats[1]

# extract minutes and seconds and sum them up
minutes, seconds = time.split(":")
total_seconds = int(minutes) * 60 + int(seconds)

# extract the command and its args
command = " ".join(stats[2:])

# if it's been long enough, send a notification
if total_seconds > MIN_NOTIFICATION_DELAY:
    notify("'%s' finished in %s" % (command, time))
