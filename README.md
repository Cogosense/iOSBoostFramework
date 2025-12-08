# A Boost library framework for iOS
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![SPM compatible](https://img.shields.io/badge/platform-iphoneos%20iphonesimulator%20macosx-blue)](https://developer.apple.com/documentation/xcode/adding-package-dependencies-to-your-app)

More information on the [Boost home page](http://www.boost.org/)

## Distribution

The frameworks are distributed using the following methods:

* As a binary XCFramework using Swift Package Manager
* As a binary XCFramework using carthage
* The iOSBoostFramework project can be included into an Xcode workspace

SPM is now the preferred method. Other methods will be deprecated in the next
major release.

To add the swift package right click your project in the Xcode project explorer,
select __Add packages...__.
* In the search field enter the package URL __https://github.com/Cogosense/Boost-iOS__
* In the __Dependency Rule__ field set the version to __1.89.0__
## Platform Support

The Makefile in this project creates a iOS XCframework bundle that
supports the following platforms:

* iphoneos arm64
* iphonesimulator x86_64 (not supported on SDK v26+)
* iphonesimulator arm64
* macosx x86_64
* macosx arm64

It is suitable for using on all iOS devices and simulators that support
iOS 11 and greater. The macosx platform supprts v10 and greater.

## Xcode Support

Xcode14 has removed support for 32bit compilation, so the armv7 device and
i386 simulator architecture have been removed.

The first release of iOSBoostFramework to support xcframeworks is 1.81.2.

The following operating systems and processors are supported:
* MacOSX on Intel and Apple processors.
* iOS on Apple 64 bit processors
* iOS Simulator on Intel and Apple processors.

The iOS Simulator for Intel processors is only supported upto Xcode 16.4,
from Xcode 26.1, the iOS simulator on x86_64 is not being built.

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
* container

The locale library has the POSIX option turned on and the libiconv library
supplied with iOS is used.

## Bitcode

The Makefile supports bitcode generation for release builds. Debug builds use
a bitcode-marker. Bitcode generation is controlled by the build variable
**ENABLE_BITCODE** and the mode is controlled by the build variable
**BITCODE_GENERATION_MODE**.

## SDK

The macosx, iphoneos and iphonesimulator SDKs are currently supported. Using the
XCFramework, a single binary can be created that supports ARM devices and
ARM and x86_64 simulators in a single framework bundle.

To build a device framework only:

    make
    make xcframework

To build a universal XCframework:

    make SDK=macosx
    make SDK=iphoneos
    make SDK=iphonesimulator
    make xcframework

Or in one line:

    for sdk in macosx iphoneos iphonesimulator ; do make SDK=$sdk ; done && make xcframework

## Active Architectures

When used in conjunction with an Xcode workspace, only the active architecture
is built. This is specified by Xcode using the **ARCHS** build variable.

## Support for Swift Package Manager

The new XCframework is distributed as a binary framework.
See [iOS Boost Framework Swift Package Distribution](https://github.com/Cogosense/Boost-iOS.git)

## Support for Xcode Workspaces

The project can be checked out into an Xcode workspace. Use Finder to drag the project file **iOSBoostFramework/iOSBoostFramework.xcodeproj** to the Xcode
workspace.

## Carthage

The Makefile was refactored to work better with the new Xcode10+ build system. The **iOSBoostFramework.xcodeproj**
file was updated to include a shared Cocoa Touch Framework target **boost**. This is required
by [Carthage](https://github.com/Carthage/Carthage).

To add **iOSBoostFramework** to your project, first create a *Cartfile* in your project's root
with the following contents:

    github "Cogosense/iOSBoostFramework" >= 1.89.0

Then build with Carthage:

    carthage update

More details on adding frameworks to a project can be found [here](https://github.com/Carthage/Carthage#adding-frameworks-to-an-application).

## Legacy Makefile (deprecated)

This has now been removed - the last version to support it was 1.73.0.
