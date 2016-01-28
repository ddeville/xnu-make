#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/functions.sh"

# default argument values
CONFIG=RELEASE
ARCH=x86_64

# first let's make sure that this script is run as root otherwise we won't be able to install at all
if [ $EUID != 0 ];
then
    fail "Please run this script as root!"
fi

# next, we need to ensure that system integrity protection is disabled on this machine (only if it's greater than 10.10)
verify_sip

# retrieve the arguments
while [[ $# > 1 ]]
do
    case "$1" in
        -c|--config ) CONFIG="$2";;
        -a|--arch ) ARCH="$2";;
        * );;
    esac
    shift
done

# make sure that we have a built version of the kernel and libsyscall specified in the arguments
kernel_location=$(kernel_build_location $CONFIG $ARCH "$SCRIPT_DIR/build")
libsyscall_location=$(libsyscall_build_location "$SCRIPT_DIR/build")

if [ ! -f $kernel_location ];
then
    fail "There is no built kernel at this location, make sure that you ran 'make': $kernel_location"
fi

if [ ! -f $libsyscall_location ];
then
    fail "There is no built libsyscall at this location, make sure that you ran 'make': $libsyscall_location"
fi

# we now have everything in place to install this kernel, ask the user one last time
confirm_install

# let's install the kernel!
cp $kernel_location /System/Library/Kernels/
kextcache -invalidate /

# let's install libsyscall!
cp $libsyscall_location /usr/lib/system/
update_dyld_shared_cache

echo "Reboot your machine by running 'sudo reboot'!"
