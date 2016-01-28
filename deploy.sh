#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/functions.sh"

# default argument values
CONFIG=RELEASE
ARCH=x86_64

# a simple function that prints an error (if given) and exits
function fail {
    if [ -n "$1" ];
    then
        echo $1
    fi
    exit 1
}

# retrieve the arguments
while [[ $# > 1 ]]
do
    case "$1" in
        -h|--host ) HOST="$2";;
        -c|--config ) CONFIG="$2";;
        -a|--arch ) ARCH="$2";;
        * );;
    esac
    shift
done

# make sure that the host is something we expect
if ! [[ $HOST =~ ^([a-zA-Z0-9]+\@)?[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]];
then
    fail "Make sure that the host has the correct format '[damien@]192.168.156.123'"
fi
