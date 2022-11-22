
# echo "WINDOWS"
# nothing windows-specific so far

# fork off into the shareď zshrc in the same folder
SCRIPT_PATH="${(%):-%N}"
source "$(dirname $SCRIPT_PATH)/shared.zshrc"
