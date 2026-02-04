// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Connor",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "Connor",
            targets: ["Connor"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", exact: "1.2.5")
    ],
    targets: [
        .executableTarget(
            name: "Connor",
            dependencies: ["SwiftTerm"],
            path: "Sources/Connor",
            exclude: [
                "Resources/AppIcon.svg",
                "Resources/Info.plist"
            ],
            resources: [
                .process("Resources/Assets.xcassets")
            ]
        ),
        .testTarget(
            name: "ConnorTests",
            dependencies: ["Connor"],
            path: "Tests/ConnorTests"
        )
    ]
)
