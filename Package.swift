// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PowerPeek",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "PowerPeek", targets: ["PowerPeek"])
    ],
    targets: [
        .executableTarget(
            name: "PowerPeek",
            path: "Sources/BatteryBar"
        )
    ]
)
