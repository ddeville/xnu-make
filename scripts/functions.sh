#!/bin/bash

# a simple function that prints an error (if given) and exits
function fail {
    if [ -n "$1" ];
    then
        echo $1
    fi
    exit 1
}

# verifies that system integrity protection is disabled on this machine or exits
function verify_sip {
    major_os_version=`sw_vers -productVersion | awk -F. '{print $2}'`
    if [ $major_os_version -ge 11 ];
    then
        sip_enabled=`/usr/bin/csrutil status | awk '/status/ {print $5}' | sed 's/\.$//'`
        if [ "$sip_enabled" = "enabled" ];
        then
            fail "Please disable System Integrity Protection!"
        fi
    fi
}

# given a config, arch and build location return the location of the built kernel
function kernel_build_location {
    config=$1
    arch=$2
    build_dir=$3

    if [ "$config" = "RELEASE" ];
    then
        kernel_filename="kernel"
    else
        kernel_filename="kernel".`echo $config | tr A-Z a-z`
    fi

    xnu_build_location="$build_dir/xnu/obj/$config"_`echo $arch | tr a-z A-Z`
    echo "$xnu_build_location/$kernel_filename"
}

# given a build location return the location of the built libsyscall
function libsyscall_build_location {
    build_dir=$1
    echo "$build_dir/xnu.libsyscall/dst/usr/lib/system/libsystem_kernel.dylib"
}

# prompt the user about installing the kernel and exits if denied
function confirm_install {
    while :
    do
        read -p "Are you sure that you want to install the kernel, this cannot be undone? [Y/n] "
        case "$REPLY" in
          y|Y|yes|YES ) break;;
          n|N|no|NO ) fail "Installation was aborted";;
          * );;
        esac
    done
}
