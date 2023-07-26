# start ssh-agent silently
eval $(ssh-agent -s) > /dev/null

# fork off into the shareď unix zshrc in the same folder
SCRIPT_PATH="${(%):-%N}"
source "$(dirname $SCRIPT_PATH)/unix.zshrc"
