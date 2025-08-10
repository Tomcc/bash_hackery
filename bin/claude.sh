# THIS SCRIPT MUST BE SOURCED!

# Enable Bedrock integration
export CLAUDE_CODE_USE_BEDROCK=1
export AWS_REGION="us-west-2"

# export ANTHROPIC_MODEL=us.anthropic.claude-3-7-sonnet-20250219-v1:0
export ANTHROPIC_MODEL="us.anthropic.claude-sonnet-4-20250514-v1:0"
export ANTHROPIC_SMALL_FAST_MODEL="us.anthropic.claude-3-5-haiku-20241022-v1:0"

# Recommended output token settings for Bedrock
export CLAUDE_CODE_MAX_OUTPUT_TOKENS=4096
export MAX_THINKING_TOKENS=1024

nvm exec 18 claude