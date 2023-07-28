
# Aliases
alias hou_dpi_low="pexp HOUDINI_UISCALE 100 && echo 'Houdini DPI set to low'"
alias hou_dpi_hi="pexp HOUDINI_UISCALE 200 && echo 'Houdini DPI set to high'"

# Add sbin to path
export PATH="/usr/local/sbin:$PATH"

# Speed up cargo
export CARGO_PROFILE_DEV_SPLIT_DEBUGINFO=unpacked
export CARGO_PROFILE_TEST_SPLIT_DEBUGINFO=unpacked

# fix histdb
HISTDB_TABULATE_CMD=(sed -e $'s/\x1f/\t/g')

# ---------------- plugins ----------------

# Secretive Config
export SSH_AUTH_SOCK="/Users/tommaso/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh"

# look for the packages in this file's directory
export ZSH_PACKAGES=""$(dirname ${(%):-%N})""

# fork off into the shareď unix zshrc in the same folder
SCRIPT_PATH="${(%):-%N}"
source "$(dirname $SCRIPT_PATH)/unix.zshrc"
