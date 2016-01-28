#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/functions.sh"

# default argument values
CONFIG=RELEASE
ARCH=x86_64

# retrieve the arguments
while [[ $# > 1 ]]
do
    case "$1" in
        -h|--host ) REMOTE_HOST="$2";;
        -c|--config ) CONFIG="$2";;
        -a|--arch ) ARCH="$2";;
        * );;
    esac
    shift
done

# make sure that the host is something we expect
if ! [[ $REMOTE_HOST =~ ^([a-zA-Z0-9]+\@)?[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]];
then
    fail "Make sure that the host has the correct format '[damien@]192.168.156.178'"
fi

# make sure that we have a built version of the kernel specified in the arguments
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

kernel_filename=$(basename $kernel_location)
libsyscall_filename=$(basename $libsyscall_location)

# create a master ssh connection so that we don't create multiple ones to execute all our commands
ssh_ctl_path="$(mktemp -d /tmp/ssh_ctl.XXXXXXXXXX)"
ssh_ctl_optn="-o ControlPath=\"$ssh_ctl_path/%L-%r@%h:%p\""
ssh -nNf -o ControlMaster=yes $ssh_ctl_optn $REMOTE_HOST

# clean up the destination build directory
clean_cmd="rm -fr ~/xnu-build;\
           mkdir -p ~/xnu-build;"
ssh $ssh_ctl_optn -t $REMOTE_HOST $clean_cmd

# copy the built kernel and libsyscall to the temp destination
rsync -e "ssh $ssh_ctl_optn" $kernel_location $REMOTE_HOST:~/xnu-build/$kernel_filename
rsync -e "ssh $ssh_ctl_optn" $libsyscall_location $REMOTE_HOST:~/xnu-build/$libsyscall_filename

# install the kernel and libsyscall by moving them to the appropriate location and invalidating the kext/dyld cache
install_cmd="echo 'You might need to authenticate to install the kernel on the remote machine.';\
             sudo cp ~/xnu-build/$kernel_filename /System/Library/Kernels/;\
             sudo kextcache -invalidate /;\
             sudo cp ~/xnu-build/$libsyscall_filename /usr/lib/system/;\
             sudo update_dyld_shared_cache;"
ssh $ssh_ctl_optn -t $REMOTE_HOST $install_cmd

# terminate the master ssh connection
ssh -O exit $ssh_ctl_optn $REMOTE_HOST
rm -r $ssh_ctl_path
