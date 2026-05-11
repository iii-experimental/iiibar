// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "iiiBar",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "iiiBar", targets: ["iiiBar"])
    ],
    targets: [
        .executableTarget(
            name: "iiiBar",
            path: "Sources/iiiBar"
        ),
        .testTarget(
            name: "iiiBarTests",
            dependencies: ["iiiBar"],
            path: "Tests/iiiBarTests"
        )
    ]
)
