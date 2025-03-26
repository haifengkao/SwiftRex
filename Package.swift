// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "SwiftRex",
    platforms: [.macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6)],
    products: [
        .library(name: "ReactiveSwiftRex", targets: ["SwiftRex", "ReactiveSwiftRex"]),
        .library(name: "RxSwiftRex", targets: ["SwiftRex", "RxSwiftRex"]),

        .library(name: "ReactiveSwiftRexDynamic", type: .dynamic, targets: ["SwiftRex", "ReactiveSwiftRex"]),
        .library(name: "RxSwiftRexDynamic", type: .dynamic, targets: ["SwiftRex", "RxSwiftRex"])
    ],
    dependencies: [
        .package(url: "https://github.com/ReactiveX/RxSwift.git", from: "6.2.0"),
        .package(url: "https://github.com/ReactiveCocoa/ReactiveSwift.git", from: "7.0.0")
    ],
    targets: [
        .target(
            name: "SwiftRex",
            exclude: ["CodeGeneration/Templates"]
        ),
        .target(name: "ReactiveSwiftRex", dependencies: ["SwiftRex", "ReactiveSwift"]),
        .target(name: "RxSwiftRex", dependencies: ["SwiftRex", "RxSwift"]),

        .testTarget(name: "SwiftRexTests", dependencies: ["SwiftRex"]),
    ],
    swiftLanguageModes: [.v6]
)
