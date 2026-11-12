// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Relato",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "Relato",
            path: "Sources/Relato",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
