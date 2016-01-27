# a makefile to build xnu without having to worry about dependencies or polluting the currently installed sdk.

MACOSX_SDK = MacOSX10.11

XNU_SRC = $(CURDIR)/externals/xnu/src

KERN_CONFIG = RELEASE
KERN_ARCHS = 'x86_64'
USER_ARCHS = 'x86_64 i386'

# these are the default rules, `all`, `install`, and `clean`

SHELL := /bin/bash

.PHONY: all
all: xnu

.PHONY: install
install: install_xnu install_libsyscall

.PHONY: clean
clean: root_check
	rm -rf $(CURDIR)/build

# make sure that we're run as root

.PHONY: root_check
root_check:
ifneq ($(shell id -u -r), 0)
	$(error "Please run as root user!")
endif

# make sure that System Integrity Protection is disabled

.PHONY: sip_check
sip_check:
# only check for SIP on 10.11 and greater
ifeq ($(shell test $(shell sw_vers -productVersion | awk -F. '{print $$2}') -ge 11; echo $$?), 0)
# if SIP is enabled, throw an error!
ifeq ($(shell /usr/bin/csrutil status | awk '/status/ {print $$5}' | sed 's/\.$$//'),enabled)
	$(error "Please disable System Integrity Protection!")
else
	@echo "System Integrity Protection is disabled."
endif
else
	@echo "System Integrity Protection is not available on this platform."
endif

# make sure that Xcode is installed

.PHONY: xcode_check
xcode_check:
ifneq ($(shell xcode-select --print-path > /dev/null; echo $$?), 0)
	$(error "Please make sure that Xcode is installed and the license has been agreed to.")
endif
	@echo "Xcode is installed."

# libsystem and other dependencies rely on some Core OS makefiles to be installed in the Xcode developer directory.
# this target does so, but only if not already installed since the user will need to authenticate to install them.

CORE_OS_MAKEFILES_SRC := $(CURDIR)/src/CoreOSMakefiles
XCODE_PATH := $(shell xcode-select --print-path)

.PHONY: core_os_makefiles
core_os_makefiles: root_check xcode_check
	if [ ! -f $(XCODE_PATH)/Makefiles/CoreOS/Xcode/BSD.xcconfig ]; \
	then \
		make --directory=$(CORE_OS_MAKEFILES_SRC) install DSTROOT=$(XCODE_PATH); \
	fi;

# make a copy of the current sdk to the build directory and create a symlink in the Xcode SDKs directory

XCODE_SDKS_DIR := $(shell xcrun -sdk macosx --show-sdk-platform-path)/Developer/SDKs
MACOSX_SDK_SRC := $(XCODE_SDKS_DIR)/$(MACOSX_SDK).sdk
MACOSX_SDK_DST := $(CURDIR)/build/sdk/$(MACOSX_SDK)-xnu.sdk
MACOSX_SDK_LNK := $(XCODE_SDKS_DIR)/$(shell basename $(MACOSX_SDK_DST))
MACOSX_SDK_XNU := $(shell echo $(MACOSX_SDK) | tr A-Z a-z)-xnu

sdk: root_check
ifeq ($(shell test -d $(MACOSX_SDK_SRC); echo $$?), 1)
	$(error "The SDK $(MACOSX_SDK) cannot be found, make sure that the latest Xcode version is installed")
endif
	mkdir -p $(MACOSX_SDK_DST)
	cd $(MACOSX_SDK_SRC) && rsync -rtpl . $(MACOSX_SDK_DST)
	plutil -replace CanonicalName -string $(MACOSX_SDK_XNU) $(MACOSX_SDK_DST)/SDKSettings.plist
	ln -sf $(MACOSX_SDK_DST) $(MACOSX_SDK_LNK)

# install the latest availability versions (a simple perl script) so that the xnu build doesn't get confused

AVAILABILITY_VERSIONS_SRC := $(CURDIR)/externals/AvailabilityVersions/src
AVAILABILITY_VERSIONS_BLD := $(CURDIR)/build/AvailabilityVersions

.PHONY: availability_versions
availability_versions: sdk
	mkdir -p $(AVAILABILITY_VERSIONS_BLD)/dst
	make --directory=$(AVAILABILITY_VERSIONS_SRC) install SRCROOT=$(AVAILABILITY_VERSIONS_SRC) \
		DSTROOT=$(AVAILABILITY_VERSIONS_BLD)/dst
	ditto $(AVAILABILITY_VERSIONS_BLD)/dst/usr/local $(MACOSX_SDK_DST)/usr/local

# xnu relies on the `ctfconvert`, `ctfdump` and `ctfmerge` tools to be in the path to correctly build.
# these tools are part of dtrace so we build the latest version and make sure to add the install dir to the path.

DTRACE_SRC := $(CURDIR)/externals/dtrace/src
DTRACE_BLD := $(CURDIR)/build/dtrace
DTRACE_DST := $(DTRACE_BLD)/dst/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/local/bin

.PHONY: dtrace
dtrace: core_os_makefiles
	mkdir -p $(DTRACE_BLD)/obj $(DTRACE_BLD)/sym $(DTRACE_BLD)/dst
	xcodebuild install -project $(DTRACE_SRC)/dtrace.xcodeproj -target ctfconvert -target ctfdump -target ctfmerge \
		ARCHS=$(KERN_ARCHS) SRCROOT=$(DTRACE_SRC) OBJROOT=$(DTRACE_BLD)/obj SYMROOT=$(DTRACE_BLD)/sym \
		DSTROOT=$(DTRACE_BLD)/dst

export PATH := $(DTRACE_DST):$(PATH)

# install the libsystem headers in our sdk

LIBSYSTEM_SRC := $(CURDIR)/externals/libsystem/src
LIBSYSTEM_BLD := $(CURDIR)/build/libsystem

.PHONY: libsystem
libsystem: core_os_makefiles availability_versions
	mkdir -p $(LIBSYSTEM_BLD)/obj $(LIBSYSTEM_BLD)/sym $(LIBSYSTEM_BLD)/dst
	xcodebuild installhdrs -project $(LIBSYSTEM_SRC)/Libsystem.xcodeproj -sdk $(MACOSX_SDK_XNU) ARCHS=$(USER_ARCHS) \
		SRCROOT=$(LIBSYSTEM_SRC) OBJROOT=$(LIBSYSTEM_BLD)/obj SYMROOT=$(LIBSYSTEM_BLD)/sym DSTROOT=$(LIBSYSTEM_BLD)/dst
	ditto $(LIBSYSTEM_BLD)/dst $(MACOSX_SDK_DST)

# install the libsyscall headers

XNU_HDRS_SRC := $(CURDIR)/externals/xnu/src
XNU_HDRS_BLD := $(CURDIR)/build/xnu.hdrs

.PHONY: xnu_hdrs
xnu_hdrs: root_check libsystem dtrace
	mkdir -p $(XNU_HDRS_BLD)/obj $(XNU_HDRS_BLD)/sym $(XNU_HDRS_BLD)/dst
	make --directory=$(XNU_HDRS_SRC) installhdrs SDKROOT=$(MACOSX_SDK_XNU) ARCH_CONFIGS=$(KERN_ARCHS) \
		SRCROOT=$(XNU_HDRS_SRC) OBJROOT=$(XNU_HDRS_BLD)/obj SYMROOT=$(XNU_HDRS_BLD)/sym DSTROOT=$(XNU_HDRS_BLD)/dst
	xcodebuild installhdrs -project $(XNU_HDRS_SRC)/libsyscall/Libsyscall.xcodeproj -sdk $(MACOSX_SDK_XNU) \
		ARCHS=$(USER_ARCHS) SRCROOT=$(XNU_HDRS_SRC)/libsyscall OBJROOT=$(XNU_HDRS_BLD)/obj \
		SYMROOT=$(XNU_HDRS_BLD)/sym DSTROOT=$(XNU_HDRS_BLD)/dst
	ditto $(XNU_HDRS_BLD)/dst $(MACOSX_SDK_DST)

# build libsyscall

LIBSYSCALL_SRC := $(CURDIR)/externals/xnu/src
LIBSYSCALL_BLD := $(CURDIR)/build/xnu.libsyscall

.PHONY: xnu_libsyscall
xnu_libsyscall: root_check xnu_hdrs
	mkdir -p $(LIBSYSCALL_BLD)/obj $(LIBSYSCALL_BLD)/sym $(LIBSYSCALL_BLD)/dst
	xcodebuild install -project $(LIBSYSCALL_SRC)/libsyscall/Libsyscall.xcodeproj -sdk $(MACOSX_SDK_XNU) \
		ARCHS=$(USER_ARCHS) SRCROOT=$(LIBSYSCALL_SRC)/libsyscall OBJROOT=$(LIBSYSCALL_BLD)/obj \
		SYMROOT=$(LIBSYSCALL_BLD)/sym DSTROOT=$(LIBSYSCALL_BLD)/dst

# build xnu

XNU_BLD := $(CURDIR)/build/xnu

.PHONY: xnu
xnu: availability_versions dtrace
	mkdir -p $(XNU_BLD)/obj $(XNU_BLD)/sym $(XNU_BLD)/dst
	make --directory=$(XNU_SRC) SDKROOT=$(MACOSX_SDK_XNU) ARCH_CONFIGS=$(KERN_ARCHS) KERNEL_CONFIGS=$(KERN_CONFIG) \
	OBJROOT=$(XNU_BLD)/obj SYMROOT=$(XNU_BLD)/sym DSTROOT=$(XNU_BLD)/dst

# install xnu locally

ifeq ($(KERN_CONFIG),RELEASE)
KERNEL_FILENAME := "kernel"
else
KERNEL_FILENAME := kernel.$(shell echo $(KERN_CONFIG) | tr A-Z a-z)
endif

.PHONY: install_xnu
install_xnu: sip_check xnu
	cp $(XNU_BLD)/obj/$(KERNEL_FILENAME) /System/Library/Kernels/
	kextcache -invalidate /
	@echo "Reboot your machine!"

# install libsyscall locally

.PHONY: install_libsyscall
install_libsyscall: sip_check xnu_libsyscall
	cp $(LIBSYSCALL_BLD)/dst/usr/lib/system/libsystem_kernel.dylib /usr/lib/system/
	update_dyld_shared_cache
	@echo "Reboot your machine!"
