#
# supports architectures armv7, armv7s, arm64, i386 and x86_64
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
# The bitcode flags are standard Xcode flags.

SHELL = /bin/bash

#
# set minimum iOS version supported
#
MIN_IOS_VER = 6.1

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

empty:=
space:= $(empty) $(empty)
comma:= ,

NAME = boost
VERSION = 1_58_0
TOPDIR = $(CURDIR)
SRCDIR = $(TOPDIR)/$(NAME)_$(VERSION)
#
# ARCHS, BUILT_PRODUCTS_DIR and DERIVED_FILE_DIR are set by xcode
# only set them if make is invoked directly
#
ARCHS ?= $(ARM_V7_ARCH) $(ARM_V7S_ARCH) $(ARM_64_ARCH) $(I386_ARCH) $(X86_64_ARCH)
BUILT_PRODUCTS_DIR ?= $(TOPDIR)/build
DERIVED_FILE_DIR ?= $(TOPDIR)/build
BUILT_PRODUCTS_DIR ?= $(TOPDIR)
TARBALL = $(NAME)_$(VERSION).tar.bz2
ARM_V7_HOST = armv7-apple-darwin
ARM_V7S_HOST = armv7s-apple-darwin
ARM_64_HOST = aarch64-apple-darwin
I386_HOST = i386-apple-darwin
X86_64_HOST = x86_64-apple-darwin
ARM_V7_ARCH = armv7
ARM_V7S_ARCH = armv7s
ARM_64_ARCH = arm64
I386_ARCH = i386
X86_64_ARCH = x86_64
FRAMEWORK_VERSION = A
FRAMEWORK_NAME = boost
FRAMEWORKBUNDLE = $(FRAMEWORK_NAME).framework
DOWNLOAD_URL = http://sourceforge.net/projects/boost/files/boost/1.58.0/$(TARBALL)

#
# The following options must be the same for all projects that
# link against this boost library
# -fvisibility=hidden
# -fvisibility-inlines-hidden
#
# (if -fvisibility=hidden is specified, then -fvisibility-inlines-hidden is unnecessary as inlines are already hidden)
#
EXTRA_CPPFLAGS = -DBOOST_AC_USE_PTHREADS -DBOOST_SP_USE_PTHREADS -stdlib=libc++ -std=gnu++11 -fvisibility=default
BOOST_LIBS = test thread atomic signals filesystem regex program_options system date_time serialization exception random

define Info_plist
<?xml version="1.0" encoding="UTF-8"?>\n
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n
<plist version="1.0">\n
<dict>\n
\t<key>CFBundleDevelopmentRegion</key>\n
\t<string>English</string>\n
\t<key>CFBundleExecutable</key>\n
\t<string>$(FRAMEWORK_NAME)</string>\n
\t<key>CFBundleIdentifier</key>\n
\t<string>org.boost</string>\n
\t<key>CFBundleInfoDictionaryVersion</key>\n
\t<string>$(VERSION)</string>\n
\t<key>CFBundlePackageType</key>\n
\t<string>FMWK</string>\n
\t<key>CFBundleSignature</key>\n
\t<string>????</string>\n
\t<key>CFBundleVersion</key>\n
\t<string>$(VERSION)</string>\n
</dict>\n
</plist>\n
endef

.PHONY: framework-build

all : env framework-build

distclean : clean
	$(RM) $(TARBALL)

clean : mostlyclean
	$(RM) -r $(BUILT_PRODUCTS_DIR)/$(FRAMEWORKBUNDLE)
	$(RM) -r $(SRCDIR)
	$(RM) $(FRAMEWORKBUNDLE).tar.bz2

mostlyclean :
	$(RM) Info.plist
	$(RM) -r $(DERIVED_FILE_DIR)/$(ARM_V7_ARCH)
	$(RM) -r $(DERIVED_FILE_DIR)/$(ARM_V7S_ARCH)
	$(RM) -r $(DERIVED_FILE_DIR)/$(ARM_64_ARCH)
	$(RM) -r $(DERIVED_FILE_DIR)/$(I386_ARCH)
	$(RM) -r $(DERIVED_FILE_DIR)/$(X86_64_ARCH)

env :
	env

$(TARBALL) :
	curl -L --retry 10 -s -o $@ $(DOWNLOAD_URL) || $(RM) $@

$(SRCDIR)/bootstrap.sh : $(TARBALL)
	tar xf $(TARBALL)
	if [ -d patches/$(VERSION) ] ; then \
	    for p in patches/$(VERSION)/* ; do \
		if [ -f $$p ] ; then \
		    patch -d $(SRCDIR) -p1 < $$p ; \
		fi ; \
	    done ; \
	fi

#
# bjam source code is not c99 compatible, setting iOS9.3
# compatibility forces c99 mode, iOS9.3 is default level for
# Xcode 7.3.1
#
$(SRCDIR)/b2 : $(SRCDIR)/bootstrap.sh
	unset IPHONEOS_DEPLOYMENT_TARGET ;\
	unset SDKROOT ;\
	cd $(SRCDIR) && ./bootstrap.sh --with-libraries=$(subst $(space),$(comma),$(BOOST_LIBS))


$(DERIVED_FILE_DIR)/$(ARM_V7_ARCH) \
$(DERIVED_FILE_DIR)/$(ARM_V7S_ARCH) \
$(DERIVED_FILE_DIR)/$(ARM_64_ARCH) \
$(DERIVED_FILE_DIR)/$(I386_ARCH) \
$(DERIVED_FILE_DIR)/$(X86_64_ARCH) :
	mkdir -p $@

$(DERIVED_FILE_DIR)/user-config-$(ARM_V7_ARCH).jam \
$(DERIVED_FILE_DIR)/user-config-$(ARM_V7S_ARCH).jam \
$(DERIVED_FILE_DIR)/user-config-$(ARM_64_ARCH).jam \
$(DERIVED_FILE_DIR)/user-config-$(I386_ARCH).jam \
$(DERIVED_FILE_DIR)/user-config-$(X86_64_ARCH).jam : $(SRCDIR)/b2
	    echo using clang : $(JAM_ARCH) > $@
	    echo "    : xcrun --sdk $(JAM_SDK) clang++" >> $@
	    echo "    : <cxxflags>\"-miphoneos-version-min=$(MIN_IOS_VER) $(XCODE_BITCODE_FLAG) -arch $(JAM_ARCH) $(EXTRA_CPPFLAGS) $(JAM_DEFINES)\"" >> $@
	    echo "      <striper>" >> $@
	    echo "    ;" >> $@

$(DERIVED_FILE_DIR)/$(ARM_V7_ARCH)/$(FRAMEWORKBUNDLE) : $(DERIVED_FILE_DIR)/$(ARM_V7_ARCH) $(DERIVED_FILE_DIR)/user-config-$(ARM_V7_ARCH).jam

$(DERIVED_FILE_DIR)/$(ARM_V7S_ARCH)/$(FRAMEWORKBUNDLE) : $(DERIVED_FILE_DIR)/$(ARM_V7S_ARCH) $(DERIVED_FILE_DIR)/user-config-$(ARM_V7S_ARCH).jam

$(DERIVED_FILE_DIR)/$(ARM_64_ARCH)/$(FRAMEWORKBUNDLE) : $(DERIVED_FILE_DIR)/$(ARM_64_ARCH) $(DERIVED_FILE_DIR)/user-config-$(ARM_64_ARCH).jam

$(DERIVED_FILE_DIR)/$(I386_ARCH)/$(FRAMEWORKBUNDLE) : $(DERIVED_FILE_DIR)/$(I386_ARCH) $(DERIVED_FILE_DIR)/user-config-$(I386_ARCH).jam

$(DERIVED_FILE_DIR)/$(X86_64_ARCH)/$(FRAMEWORKBUNDLE) : $(DERIVED_FILE_DIR)/$(X86_64_ARCH) $(DERIVED_FILE_DIR)/user-config-$(X86_64_ARCH).jam

$(DERIVED_FILE_DIR)/$(ARM_V7_ARCH)/$(FRAMEWORKBUNDLE) \
$(DERIVED_FILE_DIR)/$(ARM_V7S_ARCH)/$(FRAMEWORKBUNDLE) \
$(DERIVED_FILE_DIR)/$(ARM_64_ARCH)/$(FRAMEWORKBUNDLE) \
$(DERIVED_FILE_DIR)/$(I386_ARCH)/$(FRAMEWORKBUNDLE) \
$(DERIVED_FILE_DIR)/$(X86_64_ARCH)/$(FRAMEWORKBUNDLE) :
	cd $(SRCDIR) && \
	BOOST_BUILD_USER_CONFIG=$(DERIVED_FILE_DIR)/user-config-$(JAM_ARCH).jam \
	./b2 --build-dir="$(dir $@)" --prefix="$@" toolset=clang-darwin-$(JAM_ARCH) link=static install 

$(DERIVED_FILE_DIR)/$(ARM_V7_ARCH)/$(FRAMEWORKBUNDLE)/lib/libboost.a : JAM_SDK = iphoneos
$(DERIVED_FILE_DIR)/$(ARM_V7_ARCH)/$(FRAMEWORKBUNDLE)/lib/libboost.a : JAM_ARCH = $(ARM_V7_ARCH)
$(DERIVED_FILE_DIR)/$(ARM_V7_ARCH)/$(FRAMEWORKBUNDLE)/lib/libboost.a : JAM_DEFINES = -D_LITTLE_ENDIAN
$(DERIVED_FILE_DIR)/$(ARM_V7_ARCH)/$(FRAMEWORKBUNDLE)/lib/libboost.a : $(DERIVED_FILE_DIR)/$(ARM_V7_ARCH)/$(FRAMEWORKBUNDLE)

$(DERIVED_FILE_DIR)/$(ARM_V7S_ARCH)/$(FRAMEWORKBUNDLE)/lib/libboost.a : JAM_SDK = iphoneos
$(DERIVED_FILE_DIR)/$(ARM_V7S_ARCH)/$(FRAMEWORKBUNDLE)/lib/libboost.a : JAM_ARCH = $(ARM_V7S_ARCH)
$(DERIVED_FILE_DIR)/$(ARM_V7S_ARCH)/$(FRAMEWORKBUNDLE)/lib/libboost.a : JAM_DEFINES = -D_LITTLE_ENDIAN
$(DERIVED_FILE_DIR)/$(ARM_V7S_ARCH)/$(FRAMEWORKBUNDLE)/lib/libboost.a : $(DERIVED_FILE_DIR)/$(ARM_V7S_ARCH)/$(FRAMEWORKBUNDLE)

$(DERIVED_FILE_DIR)/$(ARM_64_ARCH)/$(FRAMEWORKBUNDLE)/lib/libboost.a : JAM_SDK = iphoneos
$(DERIVED_FILE_DIR)/$(ARM_64_ARCH)/$(FRAMEWORKBUNDLE)/lib/libboost.a : JAM_ARCH = $(ARM_64_ARCH)
$(DERIVED_FILE_DIR)/$(ARM_64_ARCH)/$(FRAMEWORKBUNDLE)/lib/libboost.a : JAM_DEFINES = -D_LITTLE_ENDIAN
$(DERIVED_FILE_DIR)/$(ARM_64_ARCH)/$(FRAMEWORKBUNDLE)/lib/libboost.a : $(DERIVED_FILE_DIR)/$(ARM_64_ARCH)/$(FRAMEWORKBUNDLE)

$(DERIVED_FILE_DIR)/$(I386_ARCH)/$(FRAMEWORKBUNDLE)/lib/libboost.a : JAM_SDK = iphonesimulator
$(DERIVED_FILE_DIR)/$(I386_ARCH)/$(FRAMEWORKBUNDLE)/lib/libboost.a : JAM_ARCH = $(I386_ARCH)
$(DERIVED_FILE_DIR)/$(I386_ARCH)/$(FRAMEWORKBUNDLE)/lib/libboost.a : $(DERIVED_FILE_DIR)/$(I386_ARCH)/$(FRAMEWORKBUNDLE)

$(DERIVED_FILE_DIR)/$(X86_64_ARCH)/$(FRAMEWORKBUNDLE)/lib/libboost.a : JAM_SDK = iphonesimulator
$(DERIVED_FILE_DIR)/$(X86_64_ARCH)/$(FRAMEWORKBUNDLE)/lib/libboost.a : JAM_ARCH = $(X86_64_ARCH)
$(DERIVED_FILE_DIR)/$(X86_64_ARCH)/$(FRAMEWORKBUNDLE)/lib/libboost.a :  $(DERIVED_FILE_DIR)/$(X86_64_ARCH)/$(FRAMEWORKBUNDLE)

$(DERIVED_FILE_DIR)/$(ARM_V7_ARCH)/$(FRAMEWORKBUNDLE)/lib/libboost.a \
$(DERIVED_FILE_DIR)/$(ARM_V7S_ARCH)/$(FRAMEWORKBUNDLE)/lib/libboost.a \
$(DERIVED_FILE_DIR)/$(ARM_64_ARCH)/$(FRAMEWORKBUNDLE)/lib/libboost.a \
$(DERIVED_FILE_DIR)/$(I386_ARCH)/$(FRAMEWORKBUNDLE)/lib/libboost.a \
$(DERIVED_FILE_DIR)/$(X86_64_ARCH)/$(FRAMEWORKBUNDLE)/lib/libboost.a : 
	cd $(dir $@) && printf "[$(JAM_ARCH)] extracting... " && \
	for ar in `find $(dir $@) -name "*.a"` ; do \
	    boostlib=`basename $$ar` ; \
	    libname=`echo $$boostlib | sed 's/.*libboost_\([^.]*\).*$$/\1/'` ; \
	    mkdir $$libname && printf "$$libname " ; \
	    (cd $$libname && xcrun -sdk $(JAM_SDK) ar -x ../$$boostlib) || { \
		echo "failed to extract $(dir $@)/$$boostlib"; \
		$(RM) $@; \
		exit 1 ; \
	    } ; \
	    for obj in `find $$libname -name '*.o'` ; do \
		file=`basename $$obj` ; \
		mv $$obj ./$${libname}_$${file} ; \
	    done ; \
	done ; \
	printf "\n" ; \
	xcrun -sdk $(JAM_SDK) ar -cruS libboost.a *.o ; \
	xcrun -sdk $(JAM_SDK) ranlib libboost.a > /dev/null 2>&1

foo$(DERIVED_FILE_DIR)/$(X86_64_ARCH)/$(FRAMEWORKBUNDLE)/lib/libboost.a : 
	cd $(dir $@) && printf "[$(JAM_ARCH)] extracting... " && \
	for ar in `find $(dir $@) -name "*.a"` ; do \
	    boostlib=`basename $$ar` ; \
	    libname=`echo $$boostlib | sed 's/.*libboost_\([^.]*\).*$$/\1/'` ; \
	    mkdir $$libname && printf "$$libname " ; \
	    (cd $$libname && xcrun -sdk $(JAM_SDK) ar -x ../$$boostlib) || { \
		echo "failed to extract $(dir $@)/$$boostlib"; \
		$(RM) $@; \
		exit 1 ; \
	    } ; \
	    for obj in `find $$libname -name '*.o'` ; do \
		file=`basename $$obj` ; \
		mv $$obj ./$${libname}_$${file} ; \
	    done ; \
	    #$(RM) -r $$libname ; \
	    #$(RM) $$ar ; \
	done ; \
	printf "\n" ; \
	xcrun -sdk $(JAM_SDK) ar -cruS libboost.a *.o ; \
	xcrun -sdk $(JAM_SDK) ranlib libboost.a > /dev/null 2>&1 ; \
	#$(RM) *.o

export Info_plist

Info.plist : Makefile
	echo -e $$Info_plist > $@

framework-build: $(addprefix $(DERIVED_FILE_DIR)/, $(addsuffix /$(FRAMEWORKBUNDLE)/lib/libboost.a, $(ARCHS))) $(FRAMEWORKBUNDLE).tar.bz2

#
# The framework-no-build target is used by Jenkins to assemble
# the results of the individual architectures built in parallel.
#
# The pipeline stash/unstash feature is used to assemble the build
# results from each parallel phase.
#
# This target depends on a built file in each framework bundle,
# if it is missing then the build fails as the master has no
# rules to build it.
#
framework-no-build: $(addprefix $(DERIVED_FILE_DIR)/, $(addsuffix /$(FRAMEWORKBUNDLE)/include/boost/config.hpp, $(ARCHS))) $(FRAMEWORKBUNDLE).tar.bz2

FIRST_ARCH = $(firstword $(ARCHS))

bundle-dirs :
	$(RM) -r $(BUILT_PRODUCTS_DIR)/$(FRAMEWORKBUNDLE)
	mkdir -p $(BUILT_PRODUCTS_DIR)/$(FRAMEWORKBUNDLE)
	mkdir $(BUILT_PRODUCTS_DIR)/$(FRAMEWORKBUNDLE)/Versions
	mkdir $(BUILT_PRODUCTS_DIR)/$(FRAMEWORKBUNDLE)/Versions/$(FRAMEWORK_VERSION)
	mkdir $(BUILT_PRODUCTS_DIR)/$(FRAMEWORKBUNDLE)/Versions/$(FRAMEWORK_VERSION)/Resources
	mkdir $(BUILT_PRODUCTS_DIR)/$(FRAMEWORKBUNDLE)/Versions/$(FRAMEWORK_VERSION)/Headers
	mkdir $(BUILT_PRODUCTS_DIR)/$(FRAMEWORKBUNDLE)/Versions/$(FRAMEWORK_VERSION)/Documentation
	ln -s $(FRAMEWORK_VERSION) $(BUILT_PRODUCTS_DIR)/$(FRAMEWORKBUNDLE)/Versions/Current
	ln -s Versions/Current/Headers $(BUILT_PRODUCTS_DIR)/$(FRAMEWORKBUNDLE)/Headers
	ln -s Versions/Current/Resources $(BUILT_PRODUCTS_DIR)/$(FRAMEWORKBUNDLE)/Resources
	ln -s Versions/Current/Documentation $(BUILT_PRODUCTS_DIR)/$(FRAMEWORKBUNDLE)/Documentation
	ln -s Versions/Current/$(FRAMEWORK_NAME) $(BUILT_PRODUCTS_DIR)/$(FRAMEWORKBUNDLE)/$(FRAMEWORK_NAME)

bundle-resources : Info.plist bundle-dirs
	cp Info.plist $(BUILT_PRODUCTS_DIR)/$(FRAMEWORKBUNDLE)/Versions/$(FRAMEWORK_VERSION)/Resources/

bundle-headers : bundle-dirs
	cp -R $(DERIVED_FILE_DIR)/$(FIRST_ARCH)/$(FRAMEWORKBUNDLE)/include/boost/  $(BUILT_PRODUCTS_DIR)/$(FRAMEWORKBUNDLE)/Versions/$(FRAMEWORK_VERSION)/Headers/

bundle-libraries : bundle-dirs
	for arch in $(ARCHS) ; do libs="$$libs $(DERIVED_FILE_DIR)/$$arch/$(FRAMEWORKBUNDLE)/lib/libboost.a" ; done ; \
	xcrun -sdk iphoneos lipo -create $$libs -o $(BUILT_PRODUCTS_DIR)/$(FRAMEWORKBUNDLE)/Versions/$(FRAMEWORK_VERSION)/$(FRAMEWORK_NAME)

$(FRAMEWORKBUNDLE) : bundle-dirs bundle-resources bundle-headers bundle-libraries

$(FRAMEWORKBUNDLE).tar.bz2 : $(FRAMEWORKBUNDLE)
	$(RM) -f $(FRAMEWORKBUNDLE).tar.bz2
	tar -C $(BUILT_PRODUCTS_DIR) -cjf $(FRAMEWORKBUNDLE).tar.bz2 $(FRAMEWORKBUNDLE)

