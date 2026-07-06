// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "DeskTodoBuddy",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "DeskTodoBuddy", targets: ["DeskTodoBuddy"])
    ],
    targets: [
        .executableTarget(
            name: "DeskTodoBuddy",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("Speech"),
                .linkedFramework("UserNotifications")
            ]
        )
    ]
)
