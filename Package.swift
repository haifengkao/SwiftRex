// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "SwiftRex",
    platforms: [.macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6)],
    products: [
        .library(name: "CombineRex", targets: ["SwiftRex", "CombineRex"])
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "SwiftRex",
            exclude: ["CodeGeneration/Templates"]
        ),
        .target(name: "CombineRex", dependencies: ["SwiftRex"]),

        .testTarget(name: "SwiftRexTests", dependencies: ["SwiftRex"]),
        .testTarget(name: "CombineRexTests", dependencies: ["CombineRex"])
    ],
    swiftLanguageModes: [.v6]
)
