#!/bin/bash

# make sure that the host is something we expect
if ! [[ $1 =~ ^([a-zA-Z0-9]+\@)?[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]];
then
    echo "Usage: ./deploy.sh [damien@]192.168.156.123"
    exit 1
fi
