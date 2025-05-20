#!/usr/bin/env -S uv run --script

# /// script
# requires-python = ">=3.13"
# dependencies = [
#   "GitPython~=3.1.44",
# ]
# ///

import argparse
import git
from datetime import datetime, timedelta, timezone
from collections import defaultdict
import os

def analyze_commit_activity(repo_path, days_to_check):
    """
    Analyzes commit activity in a Git repository, buckets commits by author and hour,
    and prints a histogram of active hours.
    """
    try:
        repo = git.Repo(repo_path)
    except git.exc.InvalidGitRepositoryError:
        print(f"Error: '{repo_path}' is not a valid Git repository.")
        return
    except git.exc.NoSuchPathError:
        print(f"Error: Repository path '{repo_path}' does not exist.")
        return

    print(f"Analyzing commits from the last {days_to_check} days in '{os.path.abspath(repo_path)}'...")

    # Fetch from all remotes to get the latest data
    print("Fetching updates from all remotes...")
    for remote in repo.remotes:
        try:
            print(f"Fetching from remote '{remote.name}'...")
            remote.fetch(prune=True)
        except git.exc.GitCommandError as e:
            print(f"Error fetching from remote '{remote.name}': {e}")
            # Decide if you want to continue or exit if a fetch fails
            # For now, we'll print the error and continue
    print("Fetch complete.")

    # Calculate the date to look back to
    since_date = datetime.now(timezone.utc) - timedelta(days=days_to_check)

    author_active_hours = defaultdict(set)

    commit_count = 0
    # Iterate over commits from all branches (local and remote-tracking)
    for commit in repo.iter_commits(all=True, since=since_date.isoformat()):
        commit_count += 1
        author_name = commit.author.name
        # committed_datetime is timezone-aware (usually UTC)
        commit_time = commit.committed_datetime

        commit_hour = commit_time.hour
        # If someone committed in an hour, also count the previous hour
        previous_hour = (commit_hour - 1 + 24) % 24

        author_active_hours[author_name].add(commit_hour)
        author_active_hours[author_name].add(previous_hour)

    if commit_count == 0:
        print(f"No commits found in the last {days_to_check} days.")
        return
    
    print(f"\nFound {commit_count} commits.")
    print("\n--- Author Activity Histogram (Unique Hours) ---")

    if not author_active_hours:
        print("No activity to display.")
        return

    # Sort authors by the number of active hours (descending)
    # then by name (ascending) as a secondary sort key for tie-breaking.
    sorted_authors = sorted(
        author_active_hours.keys(),
        key=lambda author: (len(author_active_hours[author]), author),
        reverse=True
    )

    for author in sorted_authors:
        hours_set = author_active_hours[author]
        num_active_hours = len(hours_set)
        # histogram_bar = '*' * num_active_hours # Removed
        print(f"{author}: {num_active_hours} active hour(s)") # Removed histogram_bar
        # To see the specific hours:
        # print(f"  Active hours: {sorted(list(hours_set))}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Analyze Git commit activity by author and hour.",
        formatter_class=argparse.RawTextHelpFormatter,
        epilog="""
Example usage:
  python your_script_name.py /path/to/your/repo 30

This script will output a list of authors and a simple histogram
representing the number of unique hours they were 'active' (commit hour + previous hour).
It is NOT a measure of performance or effort.
"""
    )
    parser.add_argument(
        "repo_path",
        help="Path to the local Git repository."
    )
    parser.add_argument(
        "days",
        type=int,
        help="Number of days into the past to check for commits."
    )

    args = parser.parse_args()

    if args.days <= 0:
        print("Error: Number of days must be a positive integer.")
    else:
        analyze_commit_activity(args.repo_path, args.days)