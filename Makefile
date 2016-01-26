# a makefile to build xnu without having to worry about dependencies or polluting the currently installed sdk.

ARCHS = "x86_64"
MACOSX_SDK = MacOSX10.11

# make sure that we're run as root

root_check:
ifneq ($(shell id -u -r), 0)
	$(error "Please run as root user!")
endif

all: xnu

clean: root_check
	rm -rf $(CURDIR)/build

# libsystem and other dependencies rely on some Core OS makefiles to be installed in the Xcode developer directory.
# this target does so, but only if not already installed since the user will need to authenticate to install them.

CORE_OS_MAKEFILES_SRC = $(CURDIR)/src/CoreOSMakefiles
XCODE_PATH = `xcode-select --print-path`

core_os_makefiles: root_check
	if [ ! -f $(XCODE_PATH)/Makefiles/CoreOS/Xcode/BSD.xcconfig ]; \
	then \
		make --directory=$(CORE_OS_MAKEFILES_SRC) install DSTROOT=$(XCODE_PATH); \
	fi;

# make a copy of the current sdk

MACOSX_SDK_SRC = $(CURDIR)/sdk/$(MACOSX_SDK).sdk
MACOSX_SDK_DST = $(CURDIR)/build/sdk/$(MACOSX_SDK)-xnu.sdk
MACOSX_SDK_LNK = `xcrun -sdk macosx --show-sdk-platform-path`/Developer/SDKs/`basename $(MACOSX_SDK_DST)`
MACOSX_SDK_XNU = `echo $(MACOSX_SDK) | tr A-Z a-z`-xnu

macosx_sdk: root_check
	mkdir -p $(MACOSX_SDK_DST)
	cd $(MACOSX_SDK_SRC) && rsync -rtpl . $(MACOSX_SDK_DST)
	plutil -replace CanonicalName -string $(MACOSX_SDK_XNU) $(MACOSX_SDK_DST)/SDKSettings.plist
	echo "You will need to authenticate to link the new Mac OS X SDK to a location where Xcode can find it."
	ln -sf $(MACOSX_SDK_DST) $(MACOSX_SDK_LNK)

# install the latest availability versions (a simple perl script) so that the xnu build doesn't get confused

AVAILABILITY_VERSIONS_SRC = $(CURDIR)/externals/AvailabilityVersions/src
AVAILABILITY_VERSIONS_BLD = $(CURDIR)/build/AvailabilityVersions

availability_versions: macosx_sdk
	mkdir -p $(AVAILABILITY_VERSIONS_BLD)/dst
	make --directory=$(AVAILABILITY_VERSIONS_SRC) install SRCROOT=$(AVAILABILITY_VERSIONS_SRC) \
		DSTROOT=$(AVAILABILITY_VERSIONS_BLD)/dst
	echo "You will need to authenticate to copy AvailabilityVersions to the new SDK."
	ditto $(AVAILABILITY_VERSIONS_BLD)/dst/usr/local $(MACOSX_SDK_DST)/usr/local

# xnu relies on the `ctfconvert`, `ctfdump` and `ctfmerge` tools to be in the path to correctly build.
# these tools are part of dtrace so we build the latest version and make sure to add the install dir to the path.

DTRACE_SRC = $(CURDIR)/externals/dtrace/src
DTRACE_BLD = $(CURDIR)/build/dtrace
DTRACE_DST = $(DTRACE_BLD)/dst/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/local/bin

dtrace: core_os_makefiles
	mkdir -p $(DTRACE_BLD)/obj $(DTRACE_BLD)/sym $(DTRACE_BLD)/dst
	xcodebuild install -project $(DTRACE_SRC)/dtrace.xcodeproj -target ctfconvert -target ctfdump -target ctfmerge \
		ARCHS=$(ARCHS) SRCROOT=$(DTRACE_SRC) OBJROOT=$(DTRACE_BLD)/obj SYMROOT=$(DTRACE_BLD)/sym \
		DSTROOT=$(DTRACE_BLD)/dst

export PATH := $(DTRACE_DST):$(PATH)

# install the libsystem headers in our sdk

LIBSYSTEM_SRC = $(CURDIR)/externals/libsystem/src
LIBSYSTEM_BLD = $(CURDIR)/build/libsystem

libsystem: core_os_makefiles availability_versions
	mkdir -p $(LIBSYSTEM_BLD)/obj $(LIBSYSTEM_BLD)/sym $(LIBSYSTEM_BLD)/dst
	xcodebuild installhdrs -project $(LIBSYSTEM_SRC)/Libsystem.xcodeproj -sdk $(MACOSX_SDK_XNU) ARCHS='x86_64 i386' \
		SRCROOT=$(LIBSYSTEM_SRC) OBJROOT=$(LIBSYSTEM_BLD)/obj SYMROOT=$(LIBSYSTEM_BLD)/sym DSTROOT=$(LIBSYSTEM_BLD)/dst
	ditto $(LIBSYSTEM_BLD)/dst $(MACOSX_SDK_DST)

# install the libsyscall headers

XNU_HDRS_SRC = $(CURDIR)/externals/xnu/src
XNU_HDRS_BLD = $(CURDIR)/build/xnu.hdrs

xnu_hdrs: root_check libsystem dtrace
	mkdir -p $(XNU_HDRS_BLD)/obj $(XNU_HDRS_BLD)/sym $(XNU_HDRS_BLD)/dst
	echo "You will need to authenticate to build the xnu and libsyscall headers."
	make --directory=$(XNU_HDRS_SRC) installhdrs SDKROOT=$(MACOSX_SDK_XNU) ARCH_CONFIGS=$(ARCHS) SRCROOT=$(XNU_HDRS_SRC) \
		OBJROOT=$(XNU_HDRS_BLD)/obj SYMROOT=$(XNU_HDRS_BLD)/sym DSTROOT=$(XNU_HDRS_BLD)/dst
	xcodebuild installhdrs -project $(XNU_HDRS_SRC)/libsyscall/Libsyscall.xcodeproj -sdk $(MACOSX_SDK_XNU) \
		ARCHS='x86_64 i386' SRCROOT=$(XNU_HDRS_SRC)/libsyscall OBJROOT=$(XNU_HDRS_BLD)/obj \
		SYMROOT=$(XNU_HDRS_BLD)/sym DSTROOT=$(XNU_HDRS_BLD)/dst
	ditto $(XNU_HDRS_BLD)/dst $(MACOSX_SDK_DST)

#

LIBSYSCALL_SRC = $(CURDIR)/externals/xnu/src
LIBSYSCALL_BLD = $(CURDIR)/build/xnu.libsyscall

xnu_libsyscall: root_checkxnu_hdrs
	mkdir -p $(LIBSYSCALL_BLD)/obj $(LIBSYSCALL_BLD)/sym $(LIBSYSCALL_BLD)/dst
	echo "You will need to authenticate to build libsyscall."
	xcodebuild install -project $(LIBSYSCALL_SRC)/libsyscall/Libsyscall.xcodeproj -sdk $(MACOSX_SDK_XNU) \
		ARCHS='x86_64 i386' SRCROOT=$(LIBSYSCALL_SRC)/libsyscall OBJROOT=$(LIBSYSCALL_BLD)/obj \
		SYMROOT=$(LIBSYSCALL_BLD)/sym DSTROOT=$(LIBSYSCALL_BLD)/dst

#

XNU_SRC = $(CURDIR)/externals/xnu/src
XNU_BLD = $(CURDIR)/build/xnu

xnu: xnu_libsyscall
	mkdir -p $(XNU_BLD)/obj $(XNU_BLD)/sym $(XNU_BLD)/dst
	make --directory=$(XNU_SRC) SDKROOT=$(MACOSX_SDK_XNU) ARCH_CONFIGS=$(ARCHS) KERNEL_CONFIGS=RELEASE \
	OBJROOT=$(XNU_BLD)/obj SYMROOT=$(XNU_BLD)/sym DSTROOT=$(XNU_BLD)/dst
