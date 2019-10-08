#!/bin/bash
if [ -z "$1" ]
then
    echo "Usage: set_integration.sh YOUR_INTEGRATION"
    exit 1
fi

echo "export INTEGRATION=\"$1\"" > .envrc

direnv allow . 

echo "set integration to $1"