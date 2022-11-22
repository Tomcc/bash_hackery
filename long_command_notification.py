#!/usr/bin/env python3
import sys
import os
import subprocess


def toast_osx(title, msg):
    escaped = msg.replace("\"", "\\\"")

    # put the command in a raw string
    command = [
        "osascript",
        "-e",
        f"display notification \"{escaped}\" with title \"{title}\""
    ]

    subprocess.check_call(command)

def toast_win(title, msg):
    import winotify

    # create a notification
    toast = winotify.Notification(
        app_id="Long commands",
        title=title,
        msg=msg
    )

    toast.show()


def notify(msg):
    # get tokens from the environment
    pushover_long_command_token = os.getenv("PUSHOVER_LONG_COMMAND_TOKEN")
    pushover_user = os.getenv("PUSHOVER_USER")

    if not pushover_long_command_token or not pushover_user:
        # throw exception
        raise Exception("PUSHOVER_LONG_COMMAND_TOKEN and PUSHOVER_USER aren't set")

    if sys.platform == "darwin":
        toast_osx("Command Completed", msg)
    elif sys.platform == "linux":
        # TODO: implement linux notification
        pass
    elif sys.platform == "win32":
        toast_win("Command Completed", msg)

    import http.client
    import urllib
    conn = http.client.HTTPSConnection("api.pushover.net:443")
    conn.request("POST", "/1/messages.json",
                 urllib.parse.urlencode({
                     "token": pushover_long_command_token,
                     "user": pushover_user,
                     "message": msg,
                 }), {"Content-type": "application/x-www-form-urlencoded"})
    conn.getresponse()

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
