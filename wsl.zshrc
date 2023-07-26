# This file contains special stuff that only applies to WSL

# MAKE SURE to disable PATH sharing
# https://learn.microsoft.com/en-us/windows/wsl/wsl-config#wslconf
# [interop]
# appendWindowsPath = false

# Let's add back paths that are actually safe

# code
export PATH="$PATH:/mnt/c/Users/<user>/AppData/Local/Programs/Microsoft VS Code/bin/code"

# call into linux.zshrc
SCRIPT_PATH="${(%):-%N}"
source "$(dirname $SCRIPT_PATH)/linux.zshrc"