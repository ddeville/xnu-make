# XNU make

The Mac OS X kernel, `XNU`, is open source and building it from source is fairly straightforward (mainly thanks to [yearly instructions](http://shantonu.blogspot.ie) by Shantonu Sen).

However, building the kernel requires one to install a couple of dependencies that are not available on a Mac OS X installation by default. Since these dependencies are installed in the local Xcode Developer directory, one needs to install them on each new machine that one wants to build `XNU` on.
Similarly, building `libsyscall` ends up modifying the local Mac OS X SDK in Xcode which might not be desirable.

Finally, installing `XNU` and the respective `libsystem_kernel.dylib` user-space dynamic library requires a bunch of copying and manual Terminal commands to be executed which is not ideal when one wants to quickly deploy a new version of the kernel to a virtual machine for example.

This project defines a Makefile that takes care of building `XNU`, `libsyscall` and their dependencies without modifying the current SDK. An associated deploy scripts takes care of deploying the kernel and its user-space components to a remote host, such as a virtual machine.

## Prerequisites

This repo uses a handful of submodules for `XNU` and its dependencies. These submodules point to GitHub repositories containing the Apple open-source projects and are kept up to date with each new release of the Mac OS X operating system.

So before attempting to build anything, make sure to run this on the command line:

```
git submodule update --init --recursive
```

## Building

In order to build `XNU`, one can use the `Makefile` in the root of the repo. `make` will build all the dependencies and eventually `XNU` in a `build/` folder in the root.

```
sudo make
```

By default, the `Makefile` will build both `XNU` and `libsyscall`. You can specify what to build by passing the appropriate target to `make`:

```
sudo make xnu
sudo make libsyscall
```

The `Makefile` contains some default configurations that can be tweaked by passing them as argument to the `make` command:

```
MACOSX_SDK = MacOSX10.11

XNU_SRC = $(CURDIR)/externals/xnu/src

KERN_CONFIG = RELEASE
KERN_ARCHS = 'x86_64'
USER_ARCHS = 'x86_64 i386'
```

So for example, if you want to build the development version of the kernel you would do:

```
sudo make KERN_CONFIG=DEVELOPMENT
```

It’s also important to note that the `Makefile` will use the latest version of the Mac OS X SDK as installed by Xcode (in the example above it would be `MacOSX10.11`). So make sure that you have the latest version of Xcode installed and the latest SDK available under `/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/` or wherever you have Xcode installed.

By default, the `Makefile` uses the latest open-source version of `XNU` provided with the repository. Obviously, if you’re building `XNU` from source it likely means that you made some change to the source and would like to build your own version. In this case you can override the location of the source by providing it as an argument to `make`:

```
sudo make XNU_SRC=/Users/damien/src/xnu
```

## Installing

## Deploying
