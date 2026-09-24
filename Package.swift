// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "IDCardSDK_Core",
    platforms: [.iOS(.v15)],
    products: [.library(name: "IDCardSDK_Core", targets: ["IDCardSDK_Core"])],
    targets: [
        .target(name: "IDCardSDK_Core", path: "Sources/IDCardSDK_Core"),
        .testTarget(name: "IDCardSDK_CoreTests", dependencies: ["IDCardSDK_Core"], path: "Tests/IDCardSDK_CoreTests")
    ]
)
