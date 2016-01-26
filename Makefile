# A makefile to build xnu without having to worry about dependencies

all: xnu

DTRACE_SRC = $(PWD)/src/dtrace/src
DTRACE_BLD = $(PWD)/build/dtrace
DTRACE_DST = $(DTRACE_BLD)/dst/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/local/bin

dtrace:
	mkdir -p $(DTRACE_BLD)
	cd $(DTRACE_BLD) && mkdir -p obj sym dst
	cd $(DTRACE_SRC) && xcodebuild install -target ctfconvert -target ctfdump -target ctfmerge ARCHS="x86_64" SRCROOT=$(DTRACE_SRC) OBJROOT=$(DTRACE_BLD)/obj SYMROOT=$(DTRACE_BLD)/sym DSTROOT=$(DTRACE_BLD)/dst

AVAILABILITY_VERSIONS_SRC = $(PWD)/src/AvailabilityVersions/src
AVAILABILITY_VERSIONS_BLD = $(PWD)/build/AvailabilityVersions
AVAILABILITY_VERSIONS_DST = $(AVAILABILITY_VERSIONS_BLD)/dst/usr/local/libexec

availability_versions:
	mkdir -p $(AVAILABILITY_VERSIONS_BLD)
	cd $(AVAILABILITY_VERSIONS_SRC) && make install SRCROOT=$(AVAILABILITY_VERSIONS_SRC) DSTROOT=$(AVAILABILITY_VERSIONS_BLD)/dst

XNU_SRC = $(PWD)/src/xnu/src
XNU_BLD = $(PWD)/build/xnu

export PATH := $(DTRACE_DST):$(AVAILABILITY_VERSIONS_DST):$(PATH)

xnu: dtrace availability_versions
	mkdir -p $(XNU_BLD)
	cd $(XNU_SRC) && make SDKROOT=macosx ARCH_CONFIGS=X86_64 KERNEL_CONFIGS=RELEASE OBJROOT=$(XNU_BLD)/obj SYMROOT=$(XNU_BLD)/sym DSTROOT=$(XNU_BLD)/dst
