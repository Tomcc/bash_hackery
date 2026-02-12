#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///

import sys
import os
import subprocess
import argparse


def toast_osx(title, msg):
    escaped = msg.replace('"', '\\"')

    command = [
        "osascript",
        "-e",
        f'display notification "{escaped}" with title "{title}"',
    ]

    subprocess.check_call(command)


def toast_win(title, msg):
    import winotify

    toast = winotify.Notification(app_id="Notification", title=title, msg=msg)
    toast.show()


def send_pushover(msg):
    """Send notification via Pushover (optional - skips if env vars not set)."""
    pushover_token = os.getenv("PUSHOVER_LONG_COMMAND_TOKEN")
    pushover_user = os.getenv("PUSHOVER_USER")

    if not pushover_token or not pushover_user:
        # Pushover not configured, skip silently
        return

    import http.client
    import urllib

    conn = http.client.HTTPSConnection("api.pushover.net:443")
    try:
        conn.request(
            "POST",
            "/1/messages.json",
            urllib.parse.urlencode(
                {
                    "token": pushover_token,
                    "user": pushover_user,
                    "message": msg,
                }
            ),
            {"Content-type": "application/x-www-form-urlencoded"},
        )
        conn.getresponse()
    except:
        # Silence network failures
        pass


def notify(title, msg):
    """Send notification via toast and pushover."""
    if sys.platform == "darwin":
        toast_osx(title, msg)
    elif sys.platform == "linux":
        # TODO: implement linux notification
        pass
    elif sys.platform == "win32":
        toast_win(title, msg)

    send_pushover(msg)
    print(f"{title}: {msg}")


def command_shell_hook(args):
    """Handle shell hook notifications (parse command stats from shell history)."""
    MIN_NOTIFICATION_DELAY = 30

    # stats looks like: "1025 0:00 sleep 1"
    stats = args.stats.split()

    if len(stats) < 3:
        # Not enough info, skip silently
        return

    time = stats[1]

    # Extract minutes and seconds and sum them up
    parts = time.split(":")
    if len(parts) != 2:
        return

    minutes, seconds = parts
    total_seconds = int(minutes) * 60 + int(seconds)

    # Extract the command and its args
    command = " ".join(stats[2:])

    # Only notify if it's been long enough
    if total_seconds > MIN_NOTIFICATION_DELAY:
        notify("Command Completed", f"'{command}' finished in {time}")


def command_message(args):
    """Send a direct notification message."""
    notify(args.title, args.message)


def main():
    parser = argparse.ArgumentParser(
        description="Send notifications via toast and Pushover"
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    # Shell hook subcommand
    shell_parser = subparsers.add_parser(
        "shell-hook",
        help="Parse shell command stats and notify if command took long enough",
    )
    shell_parser.add_argument(
        "stats",
        help='Command stats from shell history (e.g., "1025 0:00 sleep 1")',
    )
    shell_parser.set_defaults(func=command_shell_hook)

    # Message subcommand
    msg_parser = subparsers.add_parser(
        "message",
        help="Send a notification with a custom message",
    )
    msg_parser.add_argument("message", help="The message to send")
    msg_parser.add_argument(
        "-t",
        "--title",
        default="Notification",
        help="The notification title (default: Notification)",
    )
    msg_parser.set_defaults(func=command_message)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
