#!/usr/bin/env -S uv run --script

# /// script
# requires-python = ">=3.13"
# dependencies = [
#   "GitPython~=3.1.44",
#   "boto3~=1.34", # Added for AWS CloudWatch
# ]
# ///

import argparse
import git
from datetime import datetime, timedelta, timezone
from collections import defaultdict
import os
import boto3
from botocore.exceptions import NoCredentialsError, ClientError

# --- Configuration for CloudWatch ---
DEV_ID_TO_NAME_LOOKUP = {
    'dis-386319237309792276': 'Coleman Andersen',
    'dis-118388978280955909': 'Tommaso Checchi',
    'dis-186355113726705664': 'RyanTylerRae',
    'dis-554872815451373571': 'Ethan.Lennaman',
    'dis-232400772590075904': 'dane.curbow',    
}

CLOUDWATCH_METRIC_NAMESPACE = "ProxyMetrics"
CLOUDWATCH_METRIC_NAME = "dev_requests"
CLOUDWATCH_USER_DIMENSION = "user"
# --- End Configuration ---

def get_cloudwatch_active_hours(days_to_check, dev_id_to_name_mapping):
    """
    Fetches active hours for developers from AWS CloudWatch metrics.
    """
    print("\nFetching activity from AWS CloudWatch...")
    active_hours_by_author = defaultdict(set)
    try:
        cloudwatch = boto3.client('cloudwatch')
    except NoCredentialsError:
        print("Error: AWS credentials not found. Skipping CloudWatch analysis.")
        return active_hours_by_author
    except ClientError as e:
        print(f"Error: AWS CloudWatch client error: {e}. Skipping CloudWatch analysis.")
        return active_hours_by_author

    start_time = datetime.now(timezone.utc) - timedelta(days=days_to_check)
    end_time = datetime.now(timezone.utc)

    metric_data_queries = []
    query_id_to_author_map = {}

    try:
        paginator = cloudwatch.get_paginator('list_metrics')
        list_metrics_params = {'Namespace': CLOUDWATCH_METRIC_NAMESPACE, 'MetricName': CLOUDWATCH_METRIC_NAME}
        for page in paginator.paginate(**list_metrics_params):
            for metric in page['Metrics']:
                # Look for the "user" dimension
                user_dim = next((dim for dim in metric['Dimensions'] if dim['Name'] == CLOUDWATCH_USER_DIMENSION), None)
                if not user_dim:
                    continue
                dev_id_value = user_dim['Value']
                if not dev_id_value.startswith('dis-'):
                    continue
                if dev_id_value not in dev_id_to_name_mapping:
                    print(f"Error: CloudWatch DevId '{dev_id_value}' not found in DEV_ID_TO_NAME_LOOKUP. Exiting.")
                    exit(1)
                author_name = dev_id_to_name_mapping[dev_id_value]
                query_id = f"q{len(metric_data_queries)}"
                metric_data_queries.append({
                    'Id': query_id,
                    'MetricStat': {
                        'Metric': {
                            'Namespace': metric['Namespace'],
                            'MetricName': metric['MetricName'],
                            'Dimensions': metric['Dimensions']
                        },
                        'Period': 3600,
                        'Stat': 'Maximum'
                    },
                    'ReturnData': True
                })
                query_id_to_author_map[query_id] = author_name

        if not metric_data_queries:
            print("No relevant CloudWatch metrics found for known DevIds or matching criteria.")
            return active_hours_by_author

        all_metric_data_results = []
        for i in range(0, len(metric_data_queries), 500):
            batch_queries = metric_data_queries[i:i+500]
            response = cloudwatch.get_metric_data(
                MetricDataQueries=batch_queries,
                StartTime=start_time,
                EndTime=end_time,
                ScanBy='TimestampDescending'
            )
            all_metric_data_results.extend(response['MetricDataResults'])

        for result in all_metric_data_results:
            author = query_id_to_author_map.get(result['Id'])
            if not author:
                continue
            for timestamp, value in zip(result['Timestamps'], result['Values']):
                if value > 0:
                    active_hours_by_author[author].add(timestamp.hour)
    except ClientError as e:
        print(f"Error during CloudWatch operation: {e}. Some CloudWatch data might be missing.")
    except Exception as e:
        print(f"An unexpected error occurred during CloudWatch processing: {e}")
    return active_hours_by_author

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

    # --- Fetch and merge CloudWatch activity ---
    cloudwatch_activity = get_cloudwatch_active_hours(days_to_check, DEV_ID_TO_NAME_LOOKUP)
    for author, hours in cloudwatch_activity.items():
        author_active_hours[author].update(hours)
    print(f"Merged CloudWatch activity for {len(cloudwatch_activity)} authors.")
    # --- End CloudWatch integration ---

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