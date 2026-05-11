// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "EasyLaunch",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "EasyLaunch",
            path: "Sources/EasyLaunch"
        )
    ]
)
