#!/bin/zsh
# only for syntax highlighting

# Persistent env vars stored in the macOS Keychain instead of a plaintext ~/.pexprc.
# Also drops pexp's watcher daemon, which inherited stdout and hung `ssh host 'zsh -ilc ...'`.

KEYCHAIN_ENV_PREFIX="shell_env."
KEYCHAIN_ENV_ACCOUNT="$USER"

# Names of every stored key. The name lives in the service attribute so each output line stands
# alone, and awk keeps shell startup independent of brew-installed tools like rg.
list_keys() {
    security dump-keychain 2>/dev/null \
        | awk -F'"' -v p="$KEYCHAIN_ENV_PREFIX" \
            '$2=="svce" && index($4,p)==1 { sub("^" p, "", $4); print $4 }' \
        | sort -u
}

# Export every stored key. Batched into one `security` process: spawning it per key costs ~900ms.
load_keys() {
    local -a names=("${(@f)$(list_keys)}")
    if [[ -z "$names" ]]; then
        return 0
    fi

    local -a values
    values=("${(@f)$(printf \
        "find-generic-password -s ${KEYCHAIN_ENV_PREFIX}%s -a $KEYCHAIN_ENV_ACCOUNT -w\n" \
        "${names[@]}" | security -i 2>/dev/null)}")

    # Values arrive positionally, so a short read would silently misassign every later key.
    if (( ${#values} != ${#names} )); then
        print -u2 "load_keys: read ${#values} values for ${#names} keys, exporting none."
        return 1
    fi

    local i
    for (( i = 1; i <= ${#names}; i++ )); do
        export "${names[i]}=${values[i]}"
    done
}

# Store a key in the Keychain and export it into this shell.
save_key() {
    if [[ $# -ne 2 ]]; then
        print -u2 "Usage: save_key <NAME> <value>"
        return 1
    fi

    local name="$1" value="$2"
    if [[ ! "$name" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
        print -u2 "save_key: '$name' is not a valid variable name"
        return 1
    fi

    # `security -w` hex-encodes any value containing a newline, which reads back unusable.
    if [[ "$value" == *$'\n'* ]]; then
        print -u2 "save_key: values cannot contain newlines"
        return 1
    fi

    # Delete rather than `-U -A`, which prompts for the login password to change the item's ACL.
    # Loop because adding can silently duplicate a service, and reads then pick an arbitrary one.
    while security delete-generic-password -s "${KEYCHAIN_ENV_PREFIX}${name}" \
        -a "$KEYCHAIN_ENV_ACCOUNT" >/dev/null 2>&1; do
    done

    # The value must go through argv: `-w` reading from stdin silently truncates at 128 chars.
    # It is briefly visible to `ps` for this user, who `-A` already lets read the item anyway.
    # `-A` is what stops every later read from raising a GUI approval prompt.
    if ! security add-generic-password -s "${KEYCHAIN_ENV_PREFIX}${name}" \
        -a "$KEYCHAIN_ENV_ACCOUNT" -A -w "$value" >/dev/null; then
        print -u2 "save_key: failed to store '$name'"
        return 1
    fi

    export "$name=$value"
}

# Remove a key from the Keychain and from this shell.
delete_key() {
    if [[ $# -ne 1 ]]; then
        print -u2 "Usage: delete_key <NAME>"
        return 1
    fi

    if ! security delete-generic-password -s "${KEYCHAIN_ENV_PREFIX}$1" \
        -a "$KEYCHAIN_ENV_ACCOUNT" >/dev/null 2>&1; then
        print -u2 "delete_key: '$1' not found"
        return 1
    fi

    unset "$1"
}

load_keys
