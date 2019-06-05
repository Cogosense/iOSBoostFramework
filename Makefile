#
# supports architectures armv7, armv7s, arm64, i386, x86_64 and bitcode
#
# make - build a fat archive framework using $ARCHS, if $ARCHS is empty all architectures are built (device and simulator)
# make ARCHS=i386   \
# make ARCHS=x86_64  |
# make ARCHS=armv7    > build a thin archive framework with named architecture
# make ARCHS=armv7s  |
# make ARCHS=arm64  /
# make ARCHS='i386 x86_64' - bulid a fat archive framework with only the named architectures
#
# From xcode build script:
# make ARCHS=${ARCHS} - build all active architectures
#
# Xcode bitcode support:
# make ARCHS="armv7 arm64" ENABLE_BITCODE=YES BITCODE_GENERATION_MODE=bitcode - create bitcode
# make ARCHS="armv7 arm64" ENABLE_BITCODE=YES BITCODE_GENERATION_MODE=marker - add bitcode marker (but no real bitcode)
#
# The ENABLE_BITCODE and BITCODE_GENERATION_MODE flags are set in the Xcode project settings
#

SHELL = /bin/bash

#
# library to be built
NAME = boost
VERSION = 1_70_0

#
# Download location URL
#
TARBALL = $(NAME)_$(VERSION).tar.bz2
VERSIONDIR = $(subst _,.,$(VERSION))
DOWNLOAD_URL = http://sourceforge.net/projects/boost/files/boost/$(VERSIONDIR)/$(TARBALL)

#
# Files used to trigger builds for each architecture
# TARGET_BUILD_LIB file under install prefix that can be built directly
# TARGET_NOBUILD_ARTIFACT file under install prefix that is built indirectly
#
INSTALLED_LIB = /lib/libboost.a
INSTALLED_HEADER_DIR = /include/boost

#
# Output framework name
#
FRAMEWORK_NAME = $(NAME)

#
# The supported Xcode build architectures
#
ARM_V7_ARCH = armv7
ARM_V7S_ARCH = armv7s
ARM_64_ARCH = arm64
I386_ARCH = i386
X86_64_ARCH = x86_64

#
# SDK root directories
#
IPHONEOS_SDK_ROOT := $(shell xcrun --sdk iphoneos --show-sdk-platform-path)
IPHONESIMULATOR_SDK_ROOT := $(shell xcrun --sdk iphonesimulator --show-sdk-platform-path)

#
# set or unset warning flags
#
WFLAGS = -Wall -pedantic -Wno-unused-variable

#
# The following options must be the same for all projects that
# link against this boost library
# -fvisibility=hidden
# -fvisibility-inlines-hidden
# (if -fvisibility=hidden is specified, then -fvisibility-inlines-hidden is unnecessary as inlines are already hidden)
#
EXTRA_CPPFLAGS = -DBOOST_AC_USE_PTHREADS -DBOOST_SP_USE_PTHREADS -stdlib=libc++ -std=c++17
BOOST_LIBS = atomic date_time exception filesystem locale program_options random regex serialization system test thread chrono
JAM_PROPERTIES = visibility=global

#
# set minimum iOS version supported
#
ifneq "$(IPHONEOS_DEPLOYMENT_TARGET)" ""
    MIN_IOS_VER = $(IPHONEOS_DEPLOYMENT_TARGET)
else
    MIN_IOS_VER = 8.0
endif

#
# enable bitcode support
#
ifeq "$(ENABLE_BITCODE)" "YES"
    ifeq "$(BITCODE_GENERATION_MODE)" "marker"
	XCODE_BITCODE_FLAG = -fembed-bitcode-marker
    endif
    ifeq "$(BITCODE_GENERATION_MODE)" "bitcode"
	XCODE_BITCODE_FLAG = -fembed-bitcode
    endif
endif

#
# ARCHS and BUILT_PRODUCTS_DIR are set by xcode
# only set them if make is invoked directly
#
ARCHS ?= $(ARM_V7_ARCH) $(ARM_V7S_ARCH) $(ARM_64_ARCH) $(I386_ARCH) $(X86_64_ARCH)
BUILT_PRODUCTS_DIR ?= $(CURDIR)/build

MAKER_DIR = $(BUILT_PRODUCTS_DIR)/Maker
MAKER_ARCHIVES_DIR = $(MAKER_DIR)/Archives
MAKER_SOURCES_DIR = $(MAKER_DIR)/Sources
MAKER_BUILD_DIR = $(MAKER_DIR)/Build
MAKER_BUILDROOT_DIR = $(MAKER_DIR)/Buildroot

PKGSRCDIR = $(MAKER_SOURCES_DIR)/$(NAME)_$(VERSION)

FRAMEWORKBUNDLE = $(FRAMEWORK_NAME).framework

empty:=
space:= $(empty) $(empty)
comma:= ,

.PHONY : \
	all \
	build \
	install \
	carthage \
	clean \
	build-commence \
	build-complete \
	install-commence i\
	nstall-complete \
	dirs \
	tarball \
	bootstrap \
	jams \
	$(addprefix Jam_, $(ARCHS)) \
	builds \
	$(addprefix Build_, $(ARCHS))

all : build

build : build-commence dirs tarball bootstrap jams builds bundle build-complete

install : install-commence dirs tarball bootstrap jams builds bundle install-complete

carthage:
	carthage build --no-skip-current
	carthage archive

clean :
	$(RM) -r $(BUILT_PRODUCTS_DIR)
	$(RM) -r DerivedData
	$(RM) -r Carthage
	$(RM) *.framework.tar.bz2
	$(RM $(FRAMEWORK_NAME).zip
	$(RM) Info.plist

build-commence :
	@echo "Commencing debug build for framework: $(FRAMEWORK_NAME)"

build-complete :
	@echo "Completed debug build for framework: $(FRAMEWORK_NAME)"

install-commence :
	@echo "Commencing release build for framework: $(FRAMEWORK_NAME)"

install-complete :
	@echo "Completed release build for framework: $(FRAMEWORK_NAME)"

dirs : $(MAKER_ARCHIVES_DIR) $(MAKER_SOURCES_DIR) $(MAKER_BUILD_DIR) $(MAKER_BUILDROOT_DIR)

$(MAKER_ARCHIVES_DIR) $(MAKER_SOURCES_DIR) $(MAKER_BUILD_DIR) $(MAKER_BUILDROOT_DIR) :
	mkdir -p $@

tarball : dirs $(MAKER_ARCHIVES_DIR)/$(TARBALL)

$(MAKER_ARCHIVES_DIR)/$(TARBALL) :
	curl -L --retry 10 -s -o $@ $(DOWNLOAD_URL) || { \
	    $(RM) $@ ; \
	    exit 1 ; \
	}

bootstrap : dirs tarball $(PKGSRCDIR)/bootstrap.sh

$(PKGSRCDIR)/bootstrap.sh :
	tar -C $(MAKER_SOURCES_DIR) -xmf $(MAKER_ARCHIVES_DIR)/$(TARBALL)
	if [ -d patches/$(VERSION) ] ; then \
	    for p in patches/$(VERSION)/* ; do \
		if [ -f $$p ] ; then \
		    patch -d $(PKGSRCDIR) -p1 < $$p ; \
		fi ; \
	    done ; \
	fi

jams : dirs tarball bootstrap $(addprefix Jam_, $(ARCHS)) $(PKGSRCDIR)/b2

#
# bjam source code is not c99 compatible, setting iOS9.3
# compatibility forces c99 mode, iOS9.3 is default level for
# Xcode 7.3.1
#
$(PKGSRCDIR)/b2 : $(PKGSRCDIR)/bootstrap.sh
	unset IPHONEOS_DEPLOYMENT_TARGET ;\
	unset SDKROOT ;\
	export PATH=usr/local/bin:/usr/bin:/bin ; \
	cd $(PKGSRCDIR) && ./bootstrap.sh --with-libraries=$(subst $(space),$(comma),$(BOOST_LIBS))

builds : dirs tarball bootstrap jams $(addprefix Build_, $(ARCHS))

#
# $1 - sdk (iphoneos or iphonesimulator)
# $2 - xcode architecture (armv7, armv7s, arm64, i386, x86_64)
# $3 - boost toolchain architecture (arm, arm64, x86, x86_64)
#
define configure_template

Jam_$(2) : $(MAKER_BUILD_DIR)/$(2) $(MAKER_BUILD_DIR)/$(2)/user-config.jam

$(MAKER_BUILD_DIR)/$(2) :
	mkdir -p $$@

$(MAKER_BUILD_DIR)/$(2)/user-config.jam :
	echo using clang-darwin : $(3) > $$@
	echo "    : xcrun --sdk $(1) clang++" >> $$@
	echo "    : <cxxflags>\"-miphoneos-version-min=$$(MIN_IOS_VER) $$(XCODE_BITCODE_FLAG) -arch $(2) $$(EXTRA_CPPFLAGS) $$(JAM_DEFINES) $$(WFLAGS)\"" >> $$@
	echo "      <linkflags>\"-arch $(2)\"" >> $$@
	echo "      <striper>" >> $$@
	echo "    ;" >> $$@

Build_$(2) : $(MAKER_BUILDROOT_DIR)/$(2)/$(FRAMEWORKBUNDLE)$(INSTALLED_LIB)

$(MAKER_BUILDROOT_DIR)/$(2)/$(FRAMEWORKBUNDLE)$(INSTALLED_LIB) :
	builddir="$(MAKER_BUILDROOT_DIR)/$(2)" ; \
	installdir="$(MAKER_BUILDROOT_DIR)/$(2)/$(FRAMEWORKBUNDLE)" ; \
	cd $(PKGSRCDIR) && \
	PATH=usr/local/bin:/usr/bin:/bin ; \
	BOOST_BUILD_USER_CONFIG=$(MAKER_BUILD_DIR)/$(2)/user-config.jam \
	./b2 --build-dir="$$$$builddir" --prefix="$$$$installdir" $$(JAM_OPTIONS) toolset=clang-darwin-$(3) target-os=iphone warnings=off link=static $$(JAM_PROPERTIES) install && \
	cd $$$$installdir/lib && printf "[$(2)] extracting... " && \
	for ar in `find . -name "*.a"` ; do \
	    boostlib=`basename $$$$ar` ; \
	    if [ $$$$boostlib != libboost.a ] ; then \
		libname=`echo $$$$boostlib | sed 's/.*libboost_\([^.]*\).*$$$$/\1/'` ; \
		mkdir $$$$libname && printf "$$$$libname " ; \
		(cd $$$$libname && xcrun -sdk $(1) ar -x ../$$$$boostlib) || { \
		    echo "failed to extract $$(dir $$@)/$$$$boostlib"; \
		    $(RM) $$@; \
		    exit 1 ; \
		} ; \
		for obj in `find $$$$libname -name '*.o'` ; do \
		    file=`basename $$$$obj` ; \
		    mv $$$$obj ./$$$${libname}_$$$${file} ; \
		done ; \
		$(RM) -r $$$$libname ; \
	    fi ; \
	    $(RM) $$$$ar ; \
	done ; \
	printf "\n" ; \
	xcrun -sdk $(1) ar -cruS libboost.a *.o ; \
	xcrun -sdk $(1) ranlib libboost.a > /dev/null 2>&1 ; \
	$(RM) *.o

endef

$(eval $(call configure_template,iphoneos,$(ARM_V7_ARCH),arm))
$(eval $(call configure_template,iphoneos,$(ARM_V7S_ARCH),arm))
$(eval $(call configure_template,iphoneos,$(ARM_64_ARCH),arm64))
$(eval $(call configure_template,iphonesimulator,$(I386_ARCH),x86))
$(eval $(call configure_template,iphonesimulator,$(X86_64_ARCH),x86_64))

FIRST_ARCH = $(firstword $(ARCHS))

.PHONY : bundle-dirs bundle-headers bundle-rm-fat-library bundle-info

bundle : \
	bundle-dirs \
	bundle-headers \
	bundle-rm-fat-library \
	$(BUILT_PRODUCTS_DIR)/$(FRAMEWORKBUNDLE)/$(FRAMEWORK_NAME) \
	bundle-info \
	$(FRAMEWORKBUNDLE).tar.bz2

FRAMEWORK_DIRS = \
	$(BUILT_PRODUCTS_DIR)/$(FRAMEWORKBUNDLE) \
	$(BUILT_PRODUCTS_DIR)/$(FRAMEWORKBUNDLE)/Resources \
	$(BUILT_PRODUCTS_DIR)/$(FRAMEWORKBUNDLE)/Headers \
	$(BUILT_PRODUCTS_DIR)/$(FRAMEWORKBUNDLE)/Documentation \
	$(BUILT_PRODUCTS_DIR)/$(FRAMEWORKBUNDLE)/Modules

bundle-dirs : $(FRAMEWORK_DIRS)

$(FRAMEWORK_DIRS) :
	mkdir -p $@

bundle-headers : bundle-dirs
	rsync -r -u $(MAKER_BUILDROOT_DIR)/$(FIRST_ARCH)/$(FRAMEWORKBUNDLE)$(INSTALLED_HEADER_DIR)/* $(BUILT_PRODUCTS_DIR)/$(FRAMEWORKBUNDLE)/Headers

$(BUILT_PRODUCTS_DIR)/$(FRAMEWORKBUNDLE)/Info.plist :
	cp $(FRAMEWORK_NAME)/Info.plist $@
	/usr/libexec/plistbuddy -c "Set:CFBundleDevelopmentRegion English" $@
	/usr/libexec/plistbuddy -c "Set:CFBundleExecutable $(NAME)" $@
	/usr/libexec/plistbuddy -c "Set:CFBundleName $(FRAMEWORK_NAME)" $@
	/usr/libexec/plistbuddy -c "Set:CFBundleIdentifier com.cogosense.$(NAME)" $@

bundle-info : $(BUILT_PRODUCTS_DIR)/$(FRAMEWORKBUNDLE)/Info.plist
	verCode=$$(git tag -l '[0-9]*\.[0-9]*\.[0-9]' | wc -l) ; \
	verStr=$$(git describe --match '[0-9]*\.[0-9]*\.[0-9]' --always) ; \
	/usr/libexec/plistbuddy -c "Set:CFBundleShortVersionString $${verStr}" $< ; \
	/usr/libexec/plistbuddy -c "Set:CFBundleVersion $${verCode}" $<
	plutil -convert binary1 $<

bundle-rm-fat-library :
	$(RM) $(BUILT_PRODUCTS_DIR)/$(FRAMEWORKBUNDLE)/$(FRAMEWORK_NAME)

$(BUILT_PRODUCTS_DIR)/$(FRAMEWORKBUNDLE)/$(FRAMEWORK_NAME) : $(addprefix $(MAKER_BUILDROOT_DIR)/, $(addsuffix /$(FRAMEWORKBUNDLE)$(INSTALLED_LIB),$(ARCHS)))
	xcrun -sdk iphoneos lipo -create $^ -o $@

$(FRAMEWORKBUNDLE).tar.bz2 :
	$(RM) $(FRAMEWORKBUNDLE).tar.bz2
	tar -C $(BUILT_PRODUCTS_DIR) -cjf $(FRAMEWORKBUNDLE).tar.bz2 $(FRAMEWORKBUNDLE)

