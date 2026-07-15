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
        var out = image

        let ls = k[.leftShoulder].map(px), rs = k[.rightShoulder].map(px)
        let lh = k[.leftHip].map(px), rh = k[.rightHip].map(px)
        // Shoulder width sets the scale for every warp radius.
        let shoulderW: CGFloat = (ls != nil && rs != nil) ? max(40, abs(ls!.x - rs!.x)) : W * 0.28

        // Waist slim — pinch inward at the waist (between the hips).
        if reshape.waistSlim != 0, let lh, let rh {
            let c = CGPoint(x: (lh.x + rh.x) / 2, y: (lh.y + rh.y) / 2)
            out = pinch(out, center: c, radius: max(40, abs(lh.x - rh.x) * 1.7), scale: reshape.waistSlim * 0.4, extent: extent)
        }

        // Chest — bump between the shoulders, dropped toward mid-torso.
        if reshape.chestSize != 0, let ls, let rs {
            let sc = CGPoint(x: (ls.x + rs.x) / 2, y: (ls.y + rs.y) / 2)
            let hipY: CGFloat = (lh != nil && rh != nil) ? (lh!.y + rh!.y) / 2 : sc.y - shoulderW
            let chest = CGPoint(x: sc.x, y: sc.y + (hipY - sc.y) * 0.32)
            out = bump(out, center: chest, radius: shoulderW * 0.55, scale: reshape.chestSize * 0.4, extent: extent)
        }

        // Shoulder width — a bump at each shoulder (+ broaden, − narrow).
        if reshape.shoulderWidth != 0, let ls, let rs {
            let r = shoulderW * 0.4
            out = bump(out, center: ls, radius: r, scale: reshape.shoulderWidth * 0.25, extent: extent)
            out = bump(out, center: rs, radius: r, scale: reshape.shoulderWidth * 0.25, extent: extent)
        }

        // Arm slim — pinch each forearm (elbow↔wrist midpoint).
        if reshape.armSlim != 0 {
            for (elbow, wrist) in [(k[.leftElbow].map(px), k[.leftWrist].map(px)),
                                   (k[.rightElbow].map(px), k[.rightWrist].map(px))] {
                guard let elbow, let wrist else { continue }
                let mid = CGPoint(x: (elbow.x + wrist.x) / 2, y: (elbow.y + wrist.y) / 2)
                out = pinch(out, center: mid, radius: max(25, shoulderW * 0.3), scale: reshape.armSlim * 0.3, extent: extent)
            }
        }
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
