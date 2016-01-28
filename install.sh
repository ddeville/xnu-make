#!/bin/bash

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

# first let's make sure that this script is run as root otherwise we won't be able to install at all
if [ $EUID != 0 ];
then
    fail "Please run this script as root!"
fi

# next, we need to ensure that system integrity protection is disabled on this machine (only if it's greater than 10.10)
major_os_version=`sw_vers -productVersion | awk -F. '{print $2}'`
if [ $major_os_version -ge 11 ];
then
    sip_enabled=`/usr/bin/csrutil status | awk '/status/ {print $5}' | sed 's/\.$//'`
    if [ "$sip_enabled" = "enabled" ];
    then
        fail "Please disable System Integrity Protection!"
    fi
fi

# retrieve the arguments
while [[ $# > 1 ]]
do
    case "$1" in
        -c|--config) CONFIG="$2"
        shift;;
        -a|--arch) ARCH="$2";;
        *);;
    esac
    shift
done

# make sure that we have a built version of the kernel specified in the arguments

if [ "$CONFIG" = "RELEASE" ];
then
    kernel_filename="kernel"
else
    kernel_filename="kernel".`echo $CONFIG | tr A-Z a-z`
fi

xnu_build_location="$PWD/build/xnu/obj/$CONFIG"_`echo $ARCH | tr a-z A-Z`
kernel_build_location="$xnu_build_location/$kernel_filename"

if [ ! -f $kernel_build_location ];
then
    fail "There is no built kernel at this location, make sure that you ran 'make': $kernel_build_location"
fi

# we now have everything in place to install this kernel, ask the user one last time
while :
do
    read -p "Are you sure that you want to install the kernel, this cannot be undone? [Y/n] "
    case "$REPLY" in
      y|Y|yes|YES ) break;;
      n|N|no|NO ) fail "Installation was aborted";;
      * );;
    esac
done

# let's install the kernel
cp $kernel_build_location /System/Library/Kernels/
kextcache -invalidate /

echo "Reboot your machine by running 'sudo reboot'!"
