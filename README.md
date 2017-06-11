# A Boost library framework for iOS

More information on the [Boost home page](http://www.boost.org/)

The Makefile in this project creates a fat iOS framework bundle that supports one or more of the following architectures:

* arm64
* armv7
* armv7s
* i386
* x86_64

It is suitable for using on all iOS devices newer than iPhone3GS and simulators.

## Supported Libraries

The following boost libraries are built

* test
* thread
* atomic
* signals
* filesystem
* regex
* program_options
* system
* date_time
* serialization
* exception
* random
* locale

The locale library has the POSIX option turned on and the libiconv library supplied with iOS is used.

## Support for Xcode Workspaces

The project can be checked out into an Xcode workspace. In Xcode add the project file **iOSBoostFramework/iOSBoostFramework.xcodeproj**.
The project places the final framework boost.framework in the **BUILT_PRODUCTS_DIR** build variable specified by the workspace configuration. This directory is
searched by xcode for framework dependencies.

## Bitcode

The Makefile supports bitcode generation for release builds. Debug builds use a bitcode-marker. Bitcode generation is controlled by the build variable
**ENABLE_BITCODE** and the modeis controlled by the build variable **BITCODE_GENERATION_MODE**.


## Active Architectures

When used in conjunction with an Xcode workspace, only the active architecture is built. This is specified by Xcode using the **ARCHS** build variable.
