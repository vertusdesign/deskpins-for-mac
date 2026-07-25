// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DeskPins",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "DeskPins",
            path: "Sources/DeskPins",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("Carbon"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("ScreenCaptureKit"),
                .linkedFramework("CoreMedia"),
                .linkedFramework("IOSurface"),
            ]
        )
    ]
)
