//
//  BodyReshapeWarp.swift
//  BodyReshape
//
//  Created by David Sherlock on 2026.
//

import CoreImage
import Foundation

/// The pose-driven body reshape (waist + chest + shoulders + arms) as one
/// hand-written Metal `CIWarpKernel` — replaces the chained
/// `CIPinchDistortion` / `CIBumpDistortion`, which Core Image re-stitched into a
/// fresh Metal program every frame. One fused warp compiles once, runs one pass.
enum BodyReshapeWarp {

    /// One radial input: centre, radius, and signed strength (>0 bump/magnify,
    /// <0 pinch/slim).
    struct Region {
        var center: CGPoint
        var radius: CGFloat
        var strength: Double
    }

    private static let kernel: CIWarpKernel? = {
        guard let url = Bundle.module.url(forResource: "BodyReshapeWarp", withExtension: "metallib"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? CIWarpKernel(functionName: "bodyWarp", fromMetalLibraryData: data)
    }()

    static var isAvailable: Bool { kernel != nil }

    /// Applies waist + chest + both shoulders + both forearms in one pass. Each
    /// region is independent — a nil region contributes nothing (radius 0).
    static func apply(_ image: CIImage, extent: CGRect,
                      waist: Region?, chest: Region?,
                      shoulderL: Region?, shoulderR: Region?,
                      armL: Region?, armR: Region?) -> CIImage? {
        guard let kernel else { return nil }
        func vec(_ p: CGPoint) -> CIVector { CIVector(x: p.x, y: p.y) }
        let regions = [waist, chest, shoulderL, shoulderR, armL, armR]
            .map { $0 ?? Region(center: .zero, radius: 0, strength: 0) }
        let args: [Any] = regions.flatMap { [vec($0.center), $0.radius, $0.strength] }
        let margin = regions.map(\.radius).max() ?? 0
        return kernel.apply(extent: extent,
                            roiCallback: { _, rect in rect.insetBy(dx: -margin, dy: -margin) },
                            image: image.clampedToExtent(), arguments: args)
    }
}
