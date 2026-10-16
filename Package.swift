// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "ShortcutCoach",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0"),
    ],
    targets: [
        .executableTarget(
            name: "ShortcutCoach",
            dependencies: [.product(name: "Sparkle", package: "Sparkle")],
            path: "Sources/ShortcutCoach",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("ServiceManagement"),
                // build.sh copies Sparkle.framework into Contents/Frameworks.
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"]),
            ]
        )
    ],
    swiftLanguageModes: [.v5]
)
