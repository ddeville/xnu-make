# A makefile to build xnu without having to worry about dependencies

ARCHS = "x86_64"
XCODE_PATH = `xcode-select --print-path`
XCODE_SDK_PATH = `xcrun -sdk macosx -show-sdk-path`

all: xnu

CORE_OS_MAKEFILES_SRC = $(CURDIR)/src/CoreOSMakefiles

core_os_makefiles:
	if [ ! -f $(XCODE_PATH)/Makefiles/CoreOS/Xcode/BSD.xcconfig ]; \
	then \
		echo "You will need to authenticate to install the core os makefiles."; \
		sudo make --directory=$(CORE_OS_MAKEFILES_SRC) install DSTROOT=$(XCODE_PATH); \
	fi;

DTRACE_SRC = $(CURDIR)/externals/dtrace/src
DTRACE_BLD = $(CURDIR)/build/dtrace
DTRACE_DST = $(DTRACE_BLD)/dst/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/local/bin

dtrace: core_os_makefiles
	mkdir -p $(DTRACE_BLD)
	mkdir -p $(DTRACE_BLD)/obj $(DTRACE_BLD)/sym $(DTRACE_BLD)/dst
	xcodebuild install -project $(DTRACE_SRC)/dtrace.xcodeproj -target ctfconvert -target ctfdump -target ctfmerge \
		ARCHS=$(ARCHS) SRCROOT=$(DTRACE_SRC) OBJROOT=$(DTRACE_BLD)/obj SYMROOT=$(DTRACE_BLD)/sym \
		DSTROOT=$(DTRACE_BLD)/dst

export PATH := $(DTRACE_DST):$(PATH)

AVAILABILITY_VERSIONS_SRC = $(CURDIR)/externals/AvailabilityVersions/src
AVAILABILITY_VERSIONS_BLD = $(CURDIR)/build/AvailabilityVersions

availability_versions:
	mkdir -p $(AVAILABILITY_VERSIONS_BLD)/dst
	make --directory=$(AVAILABILITY_VERSIONS_SRC) install SRCROOT=$(AVAILABILITY_VERSIONS_SRC) \
		DSTROOT=$(AVAILABILITY_VERSIONS_BLD)/dst
	ditto $(AVAILABILITY_VERSIONS_BLD)/dst/usr/local $(XCODE_SDK_PATH)/usr/local

LIBSYSTEM_SRC = $(CURDIR)/externals/libsystem/src
LIBSYSTEM_BLD = $(CURDIR)/build/libsystem

libsystem: core_os_makefiles
	mkdir -p $(LIBSYSTEM_BLD)/obj $(LIBSYSTEM_BLD)/sym $(LIBSYSTEM_BLD)/dst
	xcodebuild installhdrs -project $(LIBSYSTEM_SRC)/Libsystem.xcodeproj -sdk macosx ARCHS='x86_64 i386' \
		SRCROOT=$(LIBSYSTEM_SRC) OBJROOT=$(LIBSYSTEM_BLD)/obj SYMROOT=$(LIBSYSTEM_BLD)/sym DSTROOT=$(LIBSYSTEM_BLD)/dst
	ditto $(LIBSYSTEM_BLD)/dst $(XCODE_SDK_PATH)

XNU_HDRS_SRC = $(CURDIR)/externals/xnu/src
XNU_HDRS_BLD = $(CURDIR)/build/xnu.hdrs

xnu_hdrs: libsystem
	mkdir -p $(XNU_HDRS_BLD)/obj $(XNU_HDRS_BLD)/sym $(XNU_HDRS_BLD)/dst
	make --directory=$(XNU_HDRS_SRC) installhdrs SDKROOT=macosx ARCH_CONFIGS=$(ARCHS) SRCROOT=$(XNU_HDRS_SRC) \
		OBJROOT=$(XNU_HDRS_BLD)/obj SYMROOT=$(XNU_HDRS_BLD)/sym DSTROOT=$(XNU_HDRS_BLD)/dst
	xcodebuild installhdrs -project $(XNU_HDRS_SRC)/libsyscall/Libsyscall.xcodeproj -sdk macosx ARCHS='x86_64 i386' \
		SRCROOT=$(XNU_HDRS_SRC)/libsyscall OBJROOT=$(XNU_HDRS_BLD)/obj SYMROOT=$(XNU_HDRS_BLD)/sym \
		DSTROOT=$(XNU_HDRS_BLD)/dst

XNU_SRC = $(CURDIR)/externals/xnu/src
XNU_BLD = $(CURDIR)/build/xnu

xnu: dtrace availability_versions xnu_hdrs
	mkdir -p $(XNU_BLD)/obj $(XNU_BLD)/sym $(XNU_BLD)/dst
	make --directory=$(XNU_SRC) SDKROOT=macosx ARCH_CONFIGS=$(ARCHS) KERNEL_CONFIGS=RELEASE OBJROOT=$(XNU_BLD)/obj \
		SYMROOT=$(XNU_BLD)/sym DSTROOT=$(XNU_BLD)/dst
