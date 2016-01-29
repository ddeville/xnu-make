# XNU make

The Mac OS X kernel, XNU, is open source and building it from source is fairly straightforward (mainly thanks to [yearly instructions](http://shantonu.blogspot.ie) by Shantonu Sen).

However, building the kernel requires one to install a couple of dependencies that are not available on a Mac OS X installation by default. Since these dependencies are installed in the local Xcode Developer directory, one needs to install them on each new machine that one wants to build XNU on.
Similarly, building `libsyscall` ends up modifying the local Mac OS X SDK in Xcode which might not be desirable.

Finally, installing XNU and the respective `libsystem_kernel.dylib` user-space dynamic library requires a bunch of copying and manual Terminal commands to be executed which is not ideal when one wants to quickly deploy a new version of the kernel to a virtual machine for example.

This project defines a Makefile that takes care of building XNU, libsyscall and their dependencies without modifying the current SDK. An associated deploy scripts takes care of deploying the kernel and its user-space components to a remote host, such as a virtual machine.

## Building

## Installing

## Deploying
