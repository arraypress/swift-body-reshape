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
        .target(
            name: "BodyReshape",
            // CoreImage kernels need -fcikernel (SPM's default Metal build won't
            // pass it), so the .metal is precompiled to the bundled .metallib.
            exclude: ["Resources/BodyReshapeWarp.ci.metal"],
            resources: [.copy("Resources/BodyReshapeWarp.metallib")]
        ),
        .testTarget(name: "BodyReshapeTests", dependencies: ["BodyReshape"]),
    ]
)

// Swift 7's import rule, today: a file must import every module whose members
// it uses, rather than leaning on another file's imports.
for target in package.targets where target.type != .system && target.type != .binary && target.type != .plugin {
    target.swiftSettings = (target.swiftSettings ?? []) + [.enableUpcomingFeature("MemberImportVisibility")]
}
