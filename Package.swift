// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VapeCalc",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "VapeCalcCore", resources: [.process("Resources")]),
        .executableTarget(name: "VapeCalc", dependencies: ["VapeCalcCore"]),
        .testTarget(name: "VapeCalcCoreTests", dependencies: ["VapeCalcCore"], exclude: ["Fixtures"]),
    ]
)
