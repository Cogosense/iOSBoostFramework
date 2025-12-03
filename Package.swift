// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let version = "1.89.0"
let moduleName = "boost"
let checksum = "410c1f3f92d2be59d60765632aee189db4b56cc4fdbd21354fda9f07d86bb120"

let package = Package(
    name: moduleName,
    platforms: [
        .iOS(.v11)
    ],
    products: [
        .library(
            name: moduleName,
            targets: [moduleName]
        )
    ],
    targets: [
        .binaryTarget(
            name: moduleName,
            url: "https://github.com/Cogosense/iOSBoostFramework/releases/download/\(version)/\(moduleName).xcframework.zip",
            checksum: checksum
        )
    ]
)
