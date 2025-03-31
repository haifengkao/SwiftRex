// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "SwiftRex",
    platforms: [.macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6)],
    products: [
        .library(name: "CombineRex", targets: ["SwiftRex", "CombineRex"]),
        .library(name: "CombineRextensions", targets: ["CombineRextensions"]),
        .library(name: "BridgeMiddleware", targets: ["BridgeMiddleware"])
    ],
    dependencies: [
        .package(url: "https://github.com/TeufelAudio/UIExtensions.git", from: "4.0.0")
    ],
    targets: [
        .target(
            name: "SwiftRex",
            exclude: ["CodeGeneration/Templates"]
        ),
        .target(name: "CombineRex", dependencies: ["SwiftRex"]),
        .target(name: "BridgeMiddleware", dependencies: ["SwiftRex"]),
        .target(name: "CombineRextensions", dependencies: ["CombineRex"]),

        .testTarget(name: "SwiftRexTests", dependencies: ["SwiftRex"]),
        .testTarget(name: "CombineRexTests", dependencies: ["CombineRex"]),
    ],
    swiftLanguageModes: [.v6]
)