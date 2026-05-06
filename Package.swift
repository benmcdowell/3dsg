// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "3dsg",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "3dsg", targets: ["ThreeDSG"]),
        .library(name: "ThreeDSGCore", targets: ["ThreeDSGCore"])
    ],
    targets: [
        .target(name: "ThreeDSGCore"),
        .executableTarget(
            name: "ThreeDSG",
            dependencies: ["ThreeDSGCore"]
        ),
        .testTarget(
            name: "ThreeDSGCoreTests",
            dependencies: ["ThreeDSGCore"]
        )
    ]
)
