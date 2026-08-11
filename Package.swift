// swift-tools-version: 5.9
import PackageDescription

// 5.9 deliberately. The manifest is compiled by whatever Swift the user has,
// and swiftLanguageModes is 6.0 only. Below 6.0 the default language mode is
// already Swift 5, which is what this code expects.
let package = Package(
    name: "Cascade",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Cascade", targets: ["Cascade"])
    ],
    targets: [
        .executableTarget(
            name: "Cascade",
            path: "Sources/Cascade",
            swiftSettings: [.unsafeFlags(["-parse-as-library"])]
        )
    ]
)
