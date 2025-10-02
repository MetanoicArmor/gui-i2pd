// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "i2pd-gui",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "i2pd-gui", targets: ["i2pd-gui"]),
    ],
    dependencies: [
        // В будущем здесь могут быть дополнительные зависимости
    ],
    targets: [
        .executableTarget(
            name: "i2pd-gui",
            dependencies: [],
            path: "Sources/i2pd-gui",
            resources: [
                .copy("i2pd")
            ]
        ),
    ]
)
