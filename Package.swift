// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PandaPlay",
    platforms: [
        .tvOS(.v15)
    ],
    products: [
        .library(
            name: "PandaPlay",
            targets: ["PandaPlay"]),
    ],
    dependencies: [
        // KSPlayer will be added here
        // .package(url: "https://github.com/kingslay/KSPlayer.git", from: "2.5.0")
    ],
    targets: [
        .target(
            name: "PandaPlay",
            dependencies: [],
            path: "PandaPlay"
        )
    ]
)
