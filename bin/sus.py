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
import json
import time
import textwrap

# --- Configuration for CloudWatch ---
DEV_ID_TO_NAME_LOOKUP = {
    'dis-386319237309792276': 'Coleman Andersen',
    'dis-118388978280955909': 'Tommaso Checchi',
    'dis-186355113726705664': 'RyanTylerRae',
    'dis-554872815451373571': 'Ethan.Lennaman',
    'dis-232400772590075904': 'dane.curbow',    
    'dis-257766574272937985': 'Dominique',
    'dis-297525955381952512': 'Lukas Raymond',
    'dis-716162001864228915': 'Rebecca Power',
    'dis-121657670800375808': 'Flaminia',
    'dis-1291176103813054536': 'Tristan',
}

CLOUDWATCH_METRIC_NAMESPACE = "ProxyMetrics"
CLOUDWATCH_METRIC_NAME = "dev_requests"
CLOUDWATCH_USER_DIMENSION = "user"
# --- End Configuration ---

# --- Configuration for Mattermost ---
MATTERMOST_ID_TO_NAME_LOOKUP = {
    '5fw3511ropywtkn8kj77pafkkh': 'Coleman Andersen',
    'gbw3fihcjifqpmwf6t7w3i7wgy': 'Tommaso Checchi',
    '7o7yzo9ng7b4mju5g81tzeeaah': 'dane.curbow',
    'cpwkoemowjye9c1hk81bjnsemc': 'Dominique',
    'tru915ttzbyyikahow9rjeqzir': 'Ethan.Lennaman',
    'qfk8wi1dh3gu8yigfy4cnfr5ih': 'Flaminia',
    'ez9cd8isufyq7mzn3kkwz6bgsy': 'Lukas Raymond',
    'js9fg4yf1iyx3qkdgercaiawwr': 'Mrmo Tarius',
    '3qe87h3irt8xdm3yypkjx8z5bo': 'Rebecca Power',
    'xgjn141paiyfu83bg3s8nq9suw': 'Tristan',
    'xrzquxho3fgdfyd6arpz3kaxia': 'RyanTylerRae',
    '58knsrd7k3dumgsdtp41cptx1w': 'Unknown???',
}

HOURS_PER_WEEK = {
    'Coleman Andersen': 40,
    'Tommaso Checchi': 40,
    'RyanTylerRae': 40,
    'Ethan.Lennaman': 40,
    'dane.curbow': 30,
    'Dominique': 30,
    'Flaminia': 30,
    'Rebecca Power': 30,
    'Tristan': 30,
    'Lukas Raymond': 10,
    'Mrmo Tarius': 10,
    'Unknown???': 1,
}

MATTERMOST_DB_USER = "mmuser"
MATTERMOST_DB_NAME = "mattermost"
MATTERMOST_INSTANCE_ENV = "MATTERMOST_INSTANCE_ID"
# --- End Configuration ---

def make_hour_id(dt):
    """
    Returns a UTC datetime at the start of the hour for the given datetime.
    """
    return dt.astimezone(timezone.utc).replace(minute=0, second=0, microsecond=0, tzinfo=timezone.utc)

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
        # get_metric_data can accept up to 500 queries per request (AWS API limit)
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
                    hour_start = make_hour_id(timestamp)
                    active_hours_by_author[author].add(hour_start)
    except ClientError as e:
        print(f"Error during CloudWatch operation: {e}. Some CloudWatch data might be missing.")
    except Exception as e:
        print(f"An unexpected error occurred during CloudWatch processing: {e}")
    return active_hours_by_author

def get_mattermost_active_hours(days_to_check, mm_id_to_name_mapping):
    """
    Fetches active hours for users from Mattermost by running a read-only SQL query via AWS SSM.
    Compresses the output with gzip and decompresses it locally.
    """
    import gzip
    import io

    print("\nFetching activity from Mattermost via AWS SSM...")
    active_hours_by_author = defaultdict(set)
    instance_id = os.environ.get(MATTERMOST_INSTANCE_ENV)
    if not instance_id:
        print(f"Error: MATTERMOST_INSTANCE env var not set. Skipping Mattermost analysis.")
        return active_hours_by_author

    print(f"Using Mattermost instance id: {instance_id!r}")

    db_password = os.environ.get("MATTERMOST_DB_PASSWORD")
    if not db_password:
        print("Error: MATTERMOST_DB_PASSWORD env var not set. Skipping Mattermost analysis.")
        return active_hours_by_author

    # Compose the bash script for SSM
    commands = textwrap.dedent(f"""\
        export PGPASSWORD="{db_password}"
        export PGUSER="{MATTERMOST_DB_USER}"
        export PGDATABASE="{MATTERMOST_DB_NAME}"
        export PGHOST="localhost"
        psql -At -F ',' -c "COPY (
                /* unique (userid, hour) buckets, newest first */
                SELECT  userid,
                        date_trunc('hour', to_timestamp(createat/1000)) AS hour_ts
                FROM    posts
                WHERE   createat > (extract(epoch from now() - interval '{days_to_check} days') * 1000)
                GROUP BY userid, hour_ts               -- removes duplicates
                ORDER BY hour_ts DESC                  -- newest rows first
            ) TO STDOUT WITH (
                FORMAT csv,
                DELIMITER '|'
            )" | gzip -c | base64
    """).splitlines()

    try:
        ssm = boto3.client('ssm')
        response = ssm.send_command(
            InstanceIds=[instance_id],
            DocumentName="AWS-RunShellScript",
            Parameters={'commands': commands},
            TimeoutSeconds=60,
        )
        command_id = response['Command']['CommandId']
        # Wait for command to finish
        for _ in range(30):
            time.sleep(2)
            output = ssm.get_command_invocation(
                CommandId=command_id,
                InstanceId=instance_id,
            )
            if output['Status'] in ('Success', 'Failed', 'Cancelled', 'TimedOut'):
                break
        else:
            print("Mattermost SSM command timed out.")
            return active_hours_by_author

        if output['Status'] != 'Success':
            print(f"Mattermost SSM command failed: {json.dumps(output, indent=2)}")
            return active_hours_by_author

        # Decompress the base64-encoded gzipped output
        import base64, gzip, io
        try:
            b64_bytes = output['StandardOutputContent'].encode('utf-8', errors='ignore')
            gzipped_bytes = base64.b64decode(b64_bytes)
            with gzip.GzipFile(fileobj=io.BytesIO(gzipped_bytes)) as gz:
                decompressed = gz.read().decode('utf-8', errors='ignore')
        except Exception as e:
            print(f"Error decompressing Mattermost output: {e}")
            return active_hours_by_author

        # Output is lines: user_id|hour_ts
        for line in decompressed.splitlines():
            line = line.strip()
            if not line or '|' not in line:
                continue
            user_id, hour_ts = line.split('|', 1)
            if user_id not in mm_id_to_name_mapping:
                print(f"Error: Mattermost user_id '{user_id}' not found in MATTERMOST_ID_TO_NAME_LOOKUP. Exiting.")
                exit(1)
            author = mm_id_to_name_mapping[user_id]
            try:
                # hour_ts is like '2024-06-13 14:00:00+00'
                dt = datetime.fromisoformat(hour_ts)
                hour_start = make_hour_id(dt)
                active_hours_by_author[author].add(hour_start)
            except Exception:
                continue

    except Exception as e:
        print(f"Error fetching Mattermost activity: {e}")
    return active_hours_by_author

def get_git_active_hours(repo_path, days_to_check):
    """
    Fetches active hours for authors from Git commits.
    """
    active_hours_by_author = defaultdict(set)
    try:
        repo = git.Repo(repo_path)
    except git.exc.InvalidGitRepositoryError:
        print(f"Error: '{repo_path}' is not a valid Git repository.")
        return active_hours_by_author
    except git.exc.NoSuchPathError:
        print(f"Error: Repository path '{repo_path}' does not exist.")
        return active_hours_by_author

    print(f"Analyzing commits from the last {days_to_check} days in '{os.path.abspath(repo_path)}'...")

    # Fetch from all remotes to get the latest data
    print("Fetching updates from all remotes...")
    for remote in repo.remotes:
        try:
            print(f"Fetching from remote '{remote.name}'...")
            remote.fetch(prune=True)
        except git.exc.GitCommandError as e:
            print(f"Error fetching from remote '{remote.name}': {e}")
    print("Fetch complete.")

    since_date = datetime.now(timezone.utc) - timedelta(days=days_to_check)
    commit_count = 0
    for commit in repo.iter_commits(all=True, since=since_date.isoformat()):
        commit_count += 1
        author_name = commit.author.name
        commit_time = commit.committed_datetime.astimezone(timezone.utc)

        # Write down this hour as an absolute timestamp
        hour_start = make_hour_id(commit_time)
        active_hours_by_author[author_name].add(hour_start)

        # "credit" the previous hour as well
        prev_hour_start = make_hour_id(commit_time - timedelta(hours=1))
        active_hours_by_author[author_name].add(prev_hour_start)
    print(f"Found {commit_count} commits.")
    return active_hours_by_author

def analyze_all_sources_activity(repo_path, days_to_check, only=None):
    """
    Aggregates active hours from Git, CloudWatch, and Mattermost.
    If 'only' is set, only that source is used.
    Prints, for each author: active hours, expected hours, and percent of expected.
    """
    author_active_hours = defaultdict(set)

    if only is None or only == "git":
        git_activity = get_git_active_hours(repo_path, days_to_check)
        for author, hours in git_activity.items():
            author_active_hours[author].update(hours)
        print(f"Merged Git activity for {len(git_activity)} authors.")

    if only is None or only == "aws":
        cloudwatch_activity = get_cloudwatch_active_hours(days_to_check, DEV_ID_TO_NAME_LOOKUP)
        for author, hours in cloudwatch_activity.items():
            author_active_hours[author].update(hours)
        print(f"Merged CloudWatch activity for {len(cloudwatch_activity)} authors.")

    if only is None or only == "mattermost":
        mattermost_activity = get_mattermost_active_hours(days_to_check, MATTERMOST_ID_TO_NAME_LOOKUP)
        for author, hours in mattermost_activity.items():
            author_active_hours[author].update(hours)
        print(f"Merged Mattermost activity for {len(mattermost_activity)} authors.")

    if not author_active_hours:
        print("No activity to display.")
        return

    print("\n--- Author Activity Histogram (Unique Hours in {} days) ---".format(days_to_check))
    sorted_authors = sorted(
        author_active_hours.keys(),
        key=lambda author: (len(author_active_hours[author]), author),
        reverse=True
    )
    for author in sorted_authors:
        hours_set = author_active_hours[author]
        num_active_hours = len(hours_set)
        # Calculate expected hours
        hours_per_week = HOURS_PER_WEEK.get(author, 40)
        hours_per_day = hours_per_week / 7
        expected_hours = hours_per_day * days_to_check
        percent = (num_active_hours / expected_hours * 100) if expected_hours > 0 else 0
        print(f"{author}: {num_active_hours} active hour(s) / {expected_hours:.1f} expected ({percent:.0f}%)")
        # To see the specific hours:
        # print(f"  Active hours: {[dt.isoformat() for dt in sorted(hours_set)]}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Analyze developer activity by author and hour from Git, AWS CloudWatch, and Mattermost.",
        formatter_class=argparse.RawTextHelpFormatter,
        epilog="""
Example usage:
  python sus.py /path/to/your/repo 30
  python sus.py /path/to/your/repo 30 --only git

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
        help="Number of days into the past to check for activity."
    )
    parser.add_argument(
        "--only",
        choices=["git", "aws", "mattermost"],
        help="Only use the specified source (git, aws (cloudwatch), or mattermost)."
    )

    args = parser.parse_args()

    if args.days <= 0:
        print("Error: Number of days must be a positive integer.")
    else:
        analyze_all_sources_activity(args.repo_path, args.days, only=args.only)