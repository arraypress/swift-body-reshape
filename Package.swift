// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "BodyReshape",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
    ],
    products: [
        // On-device, license-clean body reshaping: Vision body-pose tracking +
        // Core Image warps (slim waist, chest, arms). SPIKE — tracker + grid
        // first; warps come once the pose is proven stable enough.
        .library(name: "BodyReshape", targets: ["BodyReshape"]),
    ],
    targets: [
        .target(name: "BodyReshape"),
        .testTarget(name: "BodyReshapeTests", dependencies: ["BodyReshape"]),
    ]
)
