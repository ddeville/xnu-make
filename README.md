# XNU make

The Mac OS X kernel, `XNU`, is open source and building it from source is fairly straightforward (thanks to [yearly instructions](http://shantonu.blogspot.com) by Shantonu Sen).

However, building the kernel requires one to install a couple of dependencies that are not available on a Mac OS X installation by default (such as `ctfconvert`, `ctfdump` and `ctfmerge` that are part of the Dtrace project).

Since these dependencies are installed in the local Xcode Developer directory, one needs to install them on each new machine that one wants to build XNU on. Similarly, building `libsyscall` requires one to modify the local Mac OS X SDK in Xcode which might not be desirable.

Finally, installing XNU and the respective `libsystem_kernel.dylib` user-space dynamic library requires a bunch of copying and manual terminal commands to be executed which is not ideal when one wants to quickly deploy a new version of the kernel to a virtual machine for example.

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

An `install.sh` script is provided separately from the `Makefile` (since installing the new kernel will replace the existing one and potentially make your machine unusable, it’s best to keep it as separate as possible from the benign action of building the project).

Installation can be invoked from the command line by running:

```
sudo ./install.sh --xnu
```

As before, a bunch of default configurations are provided and can be overriden by passing arguments on the command line:

```
--config DEBUG  // install the DEBUG release
--arch x86_64   // install the x86_64 architecture
--xnu           // install XNU
--libsyscall    // install libsyscall
```

So if you wanted to install the `x86_64` release version of both `XNU` and `libsyscall` you would do:

```
sudo ./install.sh --config RELEASE --arch x86_64 --xnu --libsyscall
```

You should then reboot your machine for the changes to take effect:

```
sudo reboot
```

Note that if you’re running 10.11 or greater, System Integrity Protection will have to be disabled for the installation to succeed.

Finally, I cannot stress enough that you should **not** run this on your main machine. Running the install script will override the current kernel on your machine with the one that you just built. While it might be fine (since it’s after all the same version that the one that Apple ships with Mac OS X) it could make your system unusable if you mess things up.

Only run this script on a virtual machine and take a snapshot before so that you can easily revert if you mess things up.

## Deploying

Since checking out this repo and compiling can be slow and cumbersome on a virtual machine (or a seconday physical machine), another script `deploy.sh` lets one deploy a version of the kernel that was built locally to a remote host.

Deploying is very similar to installing but it will all be performed on the remote machine. Say that I have a user called `damien` on a virtual machine with IP address `192.168.156.178`. I could deploy my newly built kernel by running:

```
./deploy.sh --host damien@192.168.156.178 --xnu
```

Similar options are available:

```
--host 192.168.156.178  // deploy to the host at 192.168.156.178
--config DEBUG          // deploy the DEBUG release
--arch x86_64           // deploy the x86_64 architecture
--xnu                   // deploy XNU
--libsyscall            // deploy libsyscall
```

`deploy.sh` will `SSH` to the host, `rsync` the built executables to the remote machine and install them on the host. Since it can be quite annoying to repeatedly enter your password, consider setting up public key authentication with your remote (virtual) machine. You will still need to enter your password to install the components on the remote machine.
