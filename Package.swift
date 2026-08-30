// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TextSelectionKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "TextSelectionKit",
            targets: ["TextSelectionKit"]
        ),
        .library(
            name: "TextSelectionKitExample",
            targets: ["TextSelectionKitExample"]
        ),
    ],
    targets: [
        .target(
            name: "TextSelectionKit",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),
        .target(
            name: "TextSelectionKitExample",
            dependencies: ["TextSelectionKit"],
            path: "Examples/TextSelectionKitExample",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),
        .testTarget(
            name: "TextSelectionKitTests",
            dependencies: ["TextSelectionKit"],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),
    ]
)
