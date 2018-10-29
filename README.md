# A Boost library framework for iOS [![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)

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

## Bitcode

The Makefile supports bitcode generation for release builds. Debug builds use a bitcode-marker. Bitcode generation is controlled by the build variable
**ENABLE_BITCODE** and the mode is controlled by the build variable **BITCODE_GENERATION_MODE**.

## Active Architectures

When used in conjunction with an Xcode workspace, only the active architecture is built. This is specified by Xcode using the **ARCHS** build variable.

## Support for Xcode Workspaces

The project can be checked out into an Xcode workspace. Use Finder to drag the project file **iOSBoostFramework/iOSBoostFramework.xcodeproj** to the Xcode
workspace.

## Carthage

The Makefile was refactored to work better with the new Xcode10 build system. The **iOSBoostFramework.xcodeproj**
file was updated to include a shared Cocoa Touch Framework target **boost**. This is required
by [Carthage](https://github.com/Carthage/Carthage).

To add **iOSBoostFramework** to your project, first create a *Cartfile* in your project's root
with the following contents:

    github "Cogosense/iOSBoostFramework" >= 1.68.0

Then build with Carthage:

    carthage update

More details on adding frameworks to a project can be found [here](https://github.com/Carthage/Carthage#adding-frameworks-to-an-application).

## Legacy Makefile (deprecated)

**Makefile.legacy** is the original Makefile. It supports boost v1.68.0 and won't be updated any further.

To continue using the legacy Makefile use the **-f** option to make.

    make -f Makefile.legacy build

The xcodeproj file still contains the External Build Tool target **boost.framework** which
invokes make with the **-f Makefile.legacy** option. Existing usage of this project should continue
to work.
