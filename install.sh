#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/functions.sh"

# default argument values
CONFIG=RELEASE
ARCH=x86_64
INSTALL_XNU=0
INSTALL_LIBSYSCALL=0

# first let's make sure that this script is run as root otherwise we won't be able to install at all
if [ $EUID != 0 ];
then
    fail "Please run this script as root!"
fi

# next, we need to ensure that system integrity protection is disabled on this machine (only if it's greater than 10.10)
verify_sip

# retrieve the arguments
while [[ $# > 0 ]]
do
    case "$1" in
        -c|--config ) CONFIG="$2"; shift;;
        -a|--arch ) ARCH="$2"; shift;;
        -x|--xnu ) INSTALL_XNU=1;;
        -l|--libsyscall ) INSTALL_LIBSYSCALL=1;;
        * );;
    esac
    shift
done

# make sure that we are installing something
if [ $INSTALL_XNU -eq 0 ] && [ $INSTALL_LIBSYSCALL -eq 0 ];
then
    fail "You need to install something! (--xnu for XNU and --libsyscall for Libsyscall)"
fi

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
if [ $INSTALL_XNU -eq 1 ];
then
    cp $kernel_location /System/Library/Kernels/
    kextcache -invalidate /
fi

# let's install libsyscall!
if [ $INSTALL_LIBSYSCALL -eq 1 ];
then
    cp $libsyscall_location /usr/lib/system/
    update_dyld_shared_cache
fi

echo "Reboot your machine by running 'sudo reboot'!"
