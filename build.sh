#===============================================================================
# Filename:  boost.sh
# Author:    Based on the good work of Pete Goodliffe updated by Rick Boykin
#
# Copyright: (c) Copyright 2009 Pete Goodliffe
# Licence:   Please feel free to use this, with attribution
#===============================================================================
# 
# Downloads and Builds a Boost framework for the iPhone.
# Creates a set of universal libraries that can be used on an iPhone and in the
# iPhone simulator. Then creates a pseudo-framework to make using boost in Xcode
# less painful.
#
# To configure the script, define:
#    BOOST_LIBS:        which libraries to build
#    BOOST_VERSION:     version number of the boost library (e.g. 1_51_0)
#
# Then go get the source tar.bz of the boost you want to build, shove it in the
# same directory as this script, and run "./boost.sh". Grab a cuppa. And voila.
#===============================================================================

#    - chrono                   : not building
#    - context                  : not building
#    - date_time                : building
#    - exception                : not building
#    - filesystem               : building
#    - graph                    : not building
#    - graph_parallel           : not building
#    - iostreams                : not building
#    - locale                   : not building
#    - math                     : not building
#    - mpi                      : not building
#    - program_options          : building
#    - python                   : not building
#    - random                   : building
#    - regex                    : building
#    - serialization            : not building
#    - signals                  : building
#    - system                   : building
#    - test                     : building
#    - thread                   : building
#    - timer                    : not building
#    - wave                     : not building

: ${BOOST_VERSION:=1_58_0}
: ${BOOST_LIBS:="test thread atomic signals filesystem regex program_options system date_time serialization exception random"}
: ${EXTRA_CPPFLAGS:="-DBOOST_AC_USE_PTHREADS -DBOOST_SP_USE_PTHREADS -stdlib=libc++ -std=gnu++11"}

#
# The following options must be the same for all projects that
# link against this boost library
# -fvisibility=hidden
# -fvisibility-inlines-hidden
#
# (if -fvisibility=hidden is specified, then -fvisibility-inlines-hidden is
#  unnecessary as inlines are already hidden)
#
COMMON_CPPFLAGS="-fembed-bitcode -fvisibility=default -miphoneos-version-min=6.1"
EXTRA_CPPFLAGS="$COMMON_CPPFLAGS $EXTRA_CPPFLAGS"

# The EXTRA_CPPFLAGS definition works around a thread race issue in
# shared_ptr. I encountered this historically and have not verified that
# the fix is no longer required. Without using the posix thread primitives
# an invalid compare-and-swap ARM instruction (non-thread-safe) was used for the
# shared_ptr use count causing nasty and subtle bugs.
#
# Should perhaps also consider/use instead: -BOOST_SP_USE_PTHREADS

: ${TARBALLDIR:=`pwd`}
: ${SRCDIR:=`pwd`}
: ${BUILDDIR:=`pwd`/ios/build}
: ${PREFIXDIR:=`pwd`/ios/prefix}
: ${STAGEDIR:=`pwd`/ios/stage}
: ${FRAMEWORKDIR:=`pwd`/ios/Frameworks}
: ${COMPILER:="clang++"}

BOOST_TARBALL=$TARBALLDIR/boost_$BOOST_VERSION.tar.bz2
BOOST_SRC=$SRCDIR/boost_${BOOST_VERSION}

#===============================================================================

echo "BOOST_VERSION:     $BOOST_VERSION"
echo "BOOST_LIBS:        $BOOST_LIBS"
echo "BOOST_TARBALL:     $BOOST_TARBALL"
echo "BOOST_SRC:         $BOOST_SRC"
echo "BUILDDIR:          $BUILDDIR"
echo "PREFIXDIR:         $PREFIXDIR"
echo "STAGEDIR:          $STAGEDIR"
echo "FRAMEWORKDIR:      $FRAMEWORKDIR"
echo "COMPILER:          $COMPILER"
echo

#===============================================================================
# Functions
#===============================================================================

abort()
{
    echo
    echo "Aborted: $@"
    exit 1
}

doneSection()
{
    echo
    echo "    ================================================================="
    echo "    Done"
    echo
}

#===============================================================================

cleanEverything()
{
    echo Cleaning everything before we start to build...
    rm -rf $BOOST_SRC
    rm -rf $BUILDDIR
    rm -rf $PREFIXDIR
    rm -rf $STAGEDIR
    doneSection
}

#===============================================================================
fetchSource()
{
    if [ ! -e $BOOST_TARBALL ]; then
	echo "Fetching $BOOST_URL ..."
	curl -L -o $BOOST_TARBALL $BOOST_URL || abort "Unable to download $BOOST_URL"
    fi
}

#===============================================================================
unpackSource()
{
    echo Unpacking boost into $SRCDIR...
    
    [ -d $SRCDIR ]    || mkdir -p $SRCDIR
    [ -d $BOOST_SRC ] || ( cd $SRCDIR; tar xfj $BOOST_TARBALL )
    [ -d $BOOST_SRC ] && echo "    ...unpacked as $BOOST_SRC"
    doneSection
}

#===============================================================================

writeBjamUserConfig()
{
    echo Writing usr-config
    cat >> $BOOST_SRC/tools/build/v2/user-config.jam <<EOF

using clang : ios
   : xcrun --sdk iphoneos $COMPILER -miphoneos-version-min=6.1 -arch arm -arch arm64 $EXTRA_CPPFLAGS
   : <striper>
   ;
using clang : ios_sim
   : xcrun --sdk iphonesimulator $COMPILER -miphoneos-version-min=6.1 -arch i386 $EXTRA_CPPFLAGS
   : <striper>
   ;
EOF
    doneSection
}

writeBjamUserConfig158()
{
    echo Writing usr-config
    cat >> $BOOST_SRC/tools/build/src/user-config.jam <<EOF

using clang : ios
   : xcrun --sdk iphoneos $COMPILER -miphoneos-version-min=6.1 -arch arm -arch arm64 $EXTRA_CPPFLAGS
   : <striper>
   ;
using clang : ios_sim
   : xcrun --sdk iphonesimulator $COMPILER -miphoneos-version-min=6.1 -arch i386 -arch x86_64 $EXTRA_CPPFLAGS
   : <striper>
   ;
EOF
    doneSection
}

#===============================================================================

bootstrapBoost()
{
    cd $BOOST_SRC
    BOOST_LIBS_COMMA=$(echo $BOOST_LIBS | sed -e "s/ /,/g")
    echo "Bootstrapping (with libs $BOOST_LIBS_COMMA)"
    ./bootstrap.sh --with-libraries=$BOOST_LIBS_COMMA
    doneSection
}

#===============================================================================

buildBoostForiPhoneOS()
{
    cd $BOOST_SRC

    ./bjam --prefix="$PREFIXDIR" toolset=clang-ios define=_LITTLE_ENDIAN link=static install \
    || abort "Bjam iphone arm failed"
    doneSection

    mkdir $STAGEDIR

    ./bjam toolset=clang-ios_sim link=static stage --stagedir=$STAGEDIR \
    || abort "Bjam iphonesim x86 failed"
    doneSection
}

#===============================================================================

#
# Create a single fat library version from the fat arm library
# in the prefix dir and the thin i386 library in the stage dir
#
# This will give us one fat library in the build dir with all
# architectures.
#
createFatLibraries()
{
    ARM=$PREFIXDIR/lib
    I386=$STAGEDIR/lib
    rm -rf $BUILDDIR/lib
    mkdir -p $BUILDDIR/lib

    echo -n "Assembling fat libraries... "
    for ar in `find $ARM -name "*.a"` ; do
	lib=`basename $ar`
	name=`echo $ar | sed 's/.*libboost_\([^.]*\).*$/\1/'`
	echo -n "$name "
	xcrun -sdk iphoneos lipo \
	    -create \
	    "$ARM/$lib" \
	    "$I386/$lib" \
	    -o          "$BUILDDIR/lib/$lib" \
	|| abort "Lipo $lib failed"
    done
    echo
}

#
# Split the fat library in the build dir into thin libraries
# in the build dir, one for each architecture
# 
createThinLibraries()
{
    for arch in arm arm64 i386 ; do
	rm -rf $BUILDDIR/$arch
	mkdir $BUILDDIR/$arch
	echo -n "Creating $arch thin libraries... "
	for ar in `find $BUILDDIR/lib -name "*.a"` ; do
	    lib=`basename $ar`
	    name=`echo $ar | sed 's/.*libboost_\([^.]*\).*$/\1/'`
	    echo -n "$name "
	    xcrun -sdk iphoneos lipo "$ar" -thin $arch -o $BUILDDIR/$arch/$lib
	done
	echo
    done
}

createThinLibraries158()
{
    for arch in arm arm64 i386 x86_64 ; do
	rm -rf $BUILDDIR/$arch
	mkdir $BUILDDIR/$arch
	echo -n "Creating $arch thin libraries... "
	for ar in `find $BUILDDIR/lib -name "*.a"` ; do
	    lib=`basename $ar`
	    name=`echo $ar | sed 's/.*libboost_\([^.]*\).*$/\1/'`
	    echo -n "$name "
	    xcrun -sdk iphoneos lipo "$ar" -thin $arch -o $BUILDDIR/$arch/$lib
	done
	echo
    done
}

#
# Unpack all the objects into a common architecture specific
# directory. Rename the objects so that they do not collide
# as the directory will hold all objects for all boost libraries
#
extractAndRenameObjects()
{
    for arch in arm arm64 i386 ; do
	rm -rf $BUILDDIR/$arch/obj
	mkdir $BUILDDIR/$arch/obj
	echo -n "Unpacking $arch thin libraries... "
	for ar in `find $BUILDDIR/$arch -name "*.a"` ; do
	    lib=`basename $ar`
	    name=`echo $ar | sed 's/.*libboost_\([^.]*\).*$/\1/'`
	    echo -n "$name "
	    rm -rf $BUILDDIR/$arch/tmp
	    mkdir $BUILDDIR/$arch/tmp
	    (cd $BUILDDIR/$arch/tmp && xcrun -sdk iphoneos ar -x ../$lib) \
		|| abort "Ar extract $lib failed"
	    for obj in `find $BUILDDIR/$arch/tmp -name "*.o"` ; do
		file=`basename $obj`
		mv $obj $BUILDDIR/$arch/obj/${name}_${file}
	    done
	done
	echo
    done
}

extractAndRenameObjects158()
{
    for arch in arm arm64 i386 x86_64 ; do
	rm -rf $BUILDDIR/$arch/obj
	mkdir $BUILDDIR/$arch/obj
	echo -n "Unpacking $arch thin libraries... "
	for ar in `find $BUILDDIR/$arch -name "*.a"` ; do
	    lib=`basename $ar`
	    name=`echo $ar | sed 's/.*libboost_\([^.]*\).*$/\1/'`
	    echo -n "$name "
	    rm -rf $BUILDDIR/$arch/tmp
	    mkdir $BUILDDIR/$arch/tmp
	    (cd $BUILDDIR/$arch/tmp && xcrun -sdk iphoneos ar -x ../$lib) \
		|| abort "Ar extract $lib failed"
	    for obj in `find $BUILDDIR/$arch/tmp -name "*.o"` ; do
		file=`basename $obj`
		mv $obj $BUILDDIR/$arch/obj/${name}_${file}
	    done
	done
	echo
    done
}

#
# Assemble all the architecture specific objects into
# one thin archive per architecture called libboost.a
#
createThinLibBoostForEachArch()
{
    echo -n "Creating libboost.a... "
    for arch in arm arm64 i386 ; do
	rm -f $BUILDDIR/$arch/libbboost.a
	echo -n "$arch "
	(
	    #
	    # ranlib s run seperately because empty translation units
	    # print out warning, this way they can be sent to /dev/null
	    # without losing an ar warnings
	    #
	    cd $BUILDDIR/$arch && \
	    xcrun -sdk iphoneos ar -cruS libboost.a obj/*.o
	    xcrun -sdk iphoneos ranlib libboost.a > /dev/null 2>&1
	) || abort "Ar create $arch libboost.a failed"
    done
    echo
}

createThinLibBoostForEachArch158()
{
    echo -n "Creating libboost.a... "
    for arch in arm arm64 i386 x86_64 ; do
	rm -f $BUILDDIR/$arch/libbboost.a
	echo -n "$arch "
	(
	    #
	    # ranlib s run seperately because empty translation units
	    # print out warning, this way they can be sent to /dev/null
	    # without losing an ar warnings
	    #
	    cd $BUILDDIR/$arch && \
	    xcrun -sdk iphoneos ar -cruS libboost.a obj/*.o
	    xcrun -sdk iphoneos ranlib libboost.a > /dev/null 2>&1
	) || abort "Ar create $arch libboost.a failed"
    done
    echo
}

#
# Assemble the thin archives into a universal fat library
# containing all the supported architectures
#
createUniversalLibBoost()
{
    echo "Creating Universal libboost.a library..."
    xcrun -sdk iphoneos lipo \
        -create \
        -arch arm  "$BUILDDIR/arm/libboost.a" \
        -arch arm64  "$BUILDDIR/arm64/libboost.a" \
        -arch i386   "$BUILDDIR/i386/libboost.a" \
        -o           "$BUILDDIR/libboost.a" \
    || abort "Lipo universal libboost.a failed"
}

#
# Assemble the thin archives into a universal fat library
# containing all the supported architectures
#
createUniversalLibBoost158()
{
    echo "Creating Universal libboost.a library..."
    xcrun -sdk iphoneos lipo \
        -create \
        -arch arm  "$BUILDDIR/arm/libboost.a" \
        -arch arm64  "$BUILDDIR/arm64/libboost.a" \
        -arch i386   "$BUILDDIR/i386/libboost.a" \
        -arch x86_64 "$BUILDDIR/x86_64/libboost.a" \
        -o           "$BUILDDIR/libboost.a" \
    || abort "Lipo universal libboost.a failed"
}

#===============================================================================

                    VERSION_TYPE=Alpha
                  FRAMEWORK_NAME=boost
               FRAMEWORK_VERSION=A

       FRAMEWORK_CURRENT_VERSION=1

buildFramework()
{
    FRAMEWORK_BUNDLE=$FRAMEWORKDIR/$FRAMEWORK_NAME.framework

    rm -rf $FRAMEWORK_BUNDLE

    echo "Framework: Setting up directories..."
    mkdir -p $FRAMEWORK_BUNDLE
    mkdir -p $FRAMEWORK_BUNDLE/Versions
    mkdir -p $FRAMEWORK_BUNDLE/Versions/$FRAMEWORK_VERSION
    mkdir -p $FRAMEWORK_BUNDLE/Versions/$FRAMEWORK_VERSION/Resources
    mkdir -p $FRAMEWORK_BUNDLE/Versions/$FRAMEWORK_VERSION/Headers
    mkdir -p $FRAMEWORK_BUNDLE/Versions/$FRAMEWORK_VERSION/Documentation

    echo "Framework: Creating symlinks..."
    ln -s $FRAMEWORK_VERSION               $FRAMEWORK_BUNDLE/Versions/Current
    ln -s Versions/Current/Headers         $FRAMEWORK_BUNDLE/Headers
    ln -s Versions/Current/Resources       $FRAMEWORK_BUNDLE/Resources
    ln -s Versions/Current/Documentation   $FRAMEWORK_BUNDLE/Documentation
    ln -s Versions/Current/$FRAMEWORK_NAME $FRAMEWORK_BUNDLE/$FRAMEWORK_NAME

    FRAMEWORK_INSTALL_NAME=$FRAMEWORK_BUNDLE/Versions/$FRAMEWORK_VERSION/$FRAMEWORK_NAME

    cp "$BUILDDIR/libboost.a" "$FRAMEWORK_INSTALL_NAME"
    echo "Framework: Copying includes..."
    cp -r $PREFIXDIR/include/boost/*  $FRAMEWORK_BUNDLE/Headers/

    echo "Framework: Creating plist..."
    cat > $FRAMEWORK_BUNDLE/Resources/Info.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>English</string>
	<key>CFBundleExecutable</key>
	<string>${FRAMEWORK_NAME}</string>
	<key>CFBundleIdentifier</key>
	<string>org.boost</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>${BOOST_VERSION}</string>
	<key>CFBundlePackageType</key>
	<string>FMWK</string>
	<key>CFBundleSignature</key>
	<string>????</string>
	<key>CFBundleVersion</key>
	<string>${FRAMEWORK_CURRENT_VERSION}</string>
</dict>
</plist>
EOF
    doneSection
}

patchBoost()
{
    echo "Patching boost source version $BOOST_VERSION ..."

    [ -d patches/$BOOST_VERSION ] || return

    for p in patches/$BOOST_VERSION/* ; do
	if [ -f $p ] ; then
	    patch -d $BOOST_SRC -p1 < $p
	fi
    done
}

#===============================================================================
# Execution starts here
#===============================================================================

mkdir -p $BUILDDIR

case $BOOST_VERSION in
    1_53_0 )
	BOOST_URL=http://sourceforge.net/projects/boost/files/boost/1.53.0/boost_1_53_0.tar.bz2
        cleanEverything
	fetchSource
        unpackSource
	patchBoost
        writeBjamUserConfig
        bootstrapBoost
        buildBoostForiPhoneOS
        createFatLibraries
	createThinLibraries
	extractAndRenameObjects
	createThinLibBoostForEachArch
	createUniversalLibBoost
        buildFramework
        ;;
    1_55_0 )
	BOOST_URL=http://sourceforge.net/projects/boost/files/boost/1.55.0/boost_1_55_0.tar.bz2
        cleanEverything
	fetchSource
        unpackSource
	patchBoost
        writeBjamUserConfig
        bootstrapBoost
        buildBoostForiPhoneOS
        createFatLibraries
	createThinLibraries
	extractAndRenameObjects
	createThinLibBoostForEachArch
	createUniversalLibBoost
        buildFramework
        ;;
    1_58_0 )
	BOOST_URL=http://sourceforge.net/projects/boost/files/boost/1.58.0/boost_1_58_0.tar.bz2
        cleanEverything
	fetchSource
        unpackSource
	patchBoost
        writeBjamUserConfig158
        bootstrapBoost
        buildBoostForiPhoneOS
        createFatLibraries
	createThinLibraries158
	extractAndRenameObjects158
	createThinLibBoostForEachArch158
	createUniversalLibBoost158
        buildFramework
        ;;
    default )
        echo "This version ($BOOST_VERSION) is not supported"
        ;;
esac

echo "Completed successfully"

#==============================================================================
