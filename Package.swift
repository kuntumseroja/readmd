// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "read.me",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "ReadMeCore", targets: ["ReadMeCore"]),
        .executable(name: "ReadMe", targets: ["ReadMe"]),
        .executable(name: "read.me", targets: ["ReadMeCLI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.4.1"),
        .package(url: "https://github.com/JohnSundell/Splash", from: "0.16.0"),
    ],
    targets: [
        .target(name: "ReadMeCore"),
        .executableTarget(
            name: "ReadMe",
            dependencies: [
                "ReadMeCore",
                .product(name: "MarkdownUI", package: "swift-markdown-ui"),
                .product(name: "Splash", package: "Splash"),
            ]
        ),
        .executableTarget(
            name: "ReadMeCLI",
            dependencies: ["ReadMeCore"]
        ),
        .testTarget(
            name: "ReadMeCoreTests",
            dependencies: ["ReadMeCore"]
        ),
    ]
)
