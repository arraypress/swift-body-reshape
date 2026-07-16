//
//  BodyReshapeFilter.swift
//  BodyReshape
//
//  Created by David Sherlock on 2026.
//

import CoreImage
import Foundation

/// Applies the tracked ``BodyReshape`` pass with Core Image distortions at the
/// tracked joints: a waist pinch, a chest bump, shoulder bumps, and arm
/// pinches. Meant to run in SOURCE space (before any reframe/crop) so the pose
/// track lines up. One builder, for both live preview and export.
public struct BodyReshapeFilter: @unchecked Sendable {

    public let reshape: BodyReshape

    public init?(reshape: BodyReshape) {
        guard reshape.isActive else { return nil }
        self.reshape = reshape
    }

    /// `time` is source seconds; `sourceSize` the extent of `image`.
    public func apply(_ image: CIImage, at time: TimeInterval, sourceSize: CGSize) -> CIImage {
        guard let k = BodyPoseTrack.sample(at: time, keyframes: reshape.keyframes) else { return image }
        let W = sourceSize.width, H = sourceSize.height
        func px(_ p: BodyPoint) -> CGPoint { CGPoint(x: Double(p.x) * W, y: (1 - Double(p.y)) * H) }
        let extent = image.extent

        let ls = k[.leftShoulder].map(px), rs = k[.rightShoulder].map(px)
        let lh = k[.leftHip].map(px), rh = k[.rightHip].map(px)
        // Shoulder width sets the scale for every warp radius.
        let shoulderW: CGFloat = (ls != nil && rs != nil) ? max(40, abs(ls!.x - rs!.x)) : W * 0.28

        // Build each radial region (nil = disabled). Signed strength: bump = +,
        // pinch = − (matches the Metal warp / the old CI scale sign).
        typealias Region = BodyReshapeWarp.Region
        var waist: Region?
        if reshape.waistSlim != 0, let lh, let rh {
            let c = CGPoint(x: (lh.x + rh.x) / 2, y: (lh.y + rh.y) / 2)
            waist = Region(center: c, radius: max(40, abs(lh.x - rh.x) * 1.7), strength: -reshape.waistSlim * 0.4)
        }
        var chest: Region?
        if reshape.chestSize != 0, let ls, let rs {
            let sc = CGPoint(x: (ls.x + rs.x) / 2, y: (ls.y + rs.y) / 2)
            let hipY: CGFloat = (lh != nil && rh != nil) ? (lh!.y + rh!.y) / 2 : sc.y - shoulderW
            let chestC = CGPoint(x: sc.x, y: sc.y + (hipY - sc.y) * 0.32)
            chest = Region(center: chestC, radius: shoulderW * 0.55, strength: reshape.chestSize * 0.4)
        }
        var shoulderL: Region?, shoulderR: Region?
        if reshape.shoulderWidth != 0, let ls, let rs {
            let r = shoulderW * 0.4, s = reshape.shoulderWidth * 0.25
            shoulderL = Region(center: ls, radius: r, strength: s)
            shoulderR = Region(center: rs, radius: r, strength: s)
        }
        var armL: Region?, armR: Region?
        if reshape.armSlim != 0 {
            let r = max(25, shoulderW * 0.3), s = -reshape.armSlim * 0.3
            if let e = k[.leftElbow].map(px), let w = k[.leftWrist].map(px) {
                armL = Region(center: CGPoint(x: (e.x + w.x) / 2, y: (e.y + w.y) / 2), radius: r, strength: s)
            }
            if let e = k[.rightElbow].map(px), let w = k[.rightWrist].map(px) {
                armR = Region(center: CGPoint(x: (e.x + w.x) / 2, y: (e.y + w.y) / 2), radius: r, strength: s)
            }
        }

        // One fused Metal warp when available (was a chain of CIBump/CIPinch that
        // Core Image re-stitched every frame), else the Core Image fallback.
        if BodyReshapeWarp.isAvailable,
           let warped = BodyReshapeWarp.apply(image, extent: extent, waist: waist, chest: chest,
                                              shoulderL: shoulderL, shoulderR: shoulderR, armL: armL, armR: armR) {
            return warped.cropped(to: extent)
        }
        var out = image
        if let waist { out = pinch(out, center: waist.center, radius: waist.radius, scale: reshape.waistSlim * 0.4, extent: extent) }
        if let chest { out = bump(out, center: chest.center, radius: chest.radius, scale: reshape.chestSize * 0.4, extent: extent) }
        if let shoulderL { out = bump(out, center: shoulderL.center, radius: shoulderL.radius, scale: reshape.shoulderWidth * 0.25, extent: extent) }
        if let shoulderR { out = bump(out, center: shoulderR.center, radius: shoulderR.radius, scale: reshape.shoulderWidth * 0.25, extent: extent) }
        if let armL { out = pinch(out, center: armL.center, radius: armL.radius, scale: reshape.armSlim * 0.3, extent: extent) }
        if let armR { out = pinch(out, center: armR.center, radius: armR.radius, scale: reshape.armSlim * 0.3, extent: extent) }
        return out
    }

    private func pinch(_ image: CIImage, center: CGPoint, radius: CGFloat, scale: Double, extent: CGRect) -> CIImage {
        image.clampedToExtent()
            .applyingFilter("CIPinchDistortion", parameters: [
                "inputCenter": CIVector(x: center.x, y: center.y),
                "inputRadius": radius,
                "inputScale": max(-1, min(1, scale)),
            ])
            .cropped(to: extent)
    }

    private func bump(_ image: CIImage, center: CGPoint, radius: CGFloat, scale: Double, extent: CGRect) -> CIImage {
        image.clampedToExtent()
            .applyingFilter("CIBumpDistortion", parameters: [
                "inputCenter": CIVector(x: center.x, y: center.y),
                "inputRadius": radius,
                "inputScale": max(-1, min(1, scale)),
            ])
            .cropped(to: extent)
    }
}
