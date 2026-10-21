// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "BeamKit",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "BeamCore", targets: ["BeamCore"]),
        .library(name: "BeamCalc", targets: ["BeamCalc"]),
    ],
    dependencies: [
        .package(url: "https://github.com/soulverteam/SoulverCore", exact: "3.5.1"),
    ],
    targets: [
        .target(name: "BeamCore"),
        .target(name: "BeamCalc", dependencies: ["BeamCore", .product(name: "SoulverCore", package: "SoulverCore")]),
        .testTarget(name: "BeamCoreTests", dependencies: ["BeamCore"]),
        .testTarget(name: "BeamCalcTests", dependencies: ["BeamCalc"]),
    ]
)
