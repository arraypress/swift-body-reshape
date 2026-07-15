//
//  BodyReshape.swift
//  BodyReshape
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// A pose-driven body reshape pass: slim the waist, resize the chest, widen or
/// narrow the shoulders, slim the arms — geometric warps at the tracked joints
/// (no generative model, on-device, license clean). Signed amounts (`-1…1`)
/// go both ways; unsigned (`0…1`) are one-directional. Feed the tracked
/// ``keyframes`` from ``BodyPoseTracker`` and apply with ``BodyReshapeFilter``.
public struct BodyReshape: Codable, Equatable, Sendable {

    /// Waist slimming (`0` = off … `1` = strong).
    public var waistSlim: Double
    /// Chest size (`-1` = smaller … `+1` = larger).
    public var chestSize: Double
    /// Shoulder width (`-1` = narrower … `+1` = broader).
    public var shoulderWidth: Double
    /// Arm slimming (`0` = off … `1` = strong).
    public var armSlim: Double
    /// The tracked body pose over time.
    public var keyframes: [BodyPoseFrame]

    public init(
        waistSlim: Double = 0,
        chestSize: Double = 0,
        shoulderWidth: Double = 0,
        armSlim: Double = 0,
        keyframes: [BodyPoseFrame] = []
    ) {
        self.waistSlim = waistSlim
        self.chestSize = chestSize
        self.shoulderWidth = shoulderWidth
        self.armSlim = armSlim
        self.keyframes = keyframes
    }

    /// Whether the pass does anything (has a track and a non-zero amount).
    public var isActive: Bool {
        !keyframes.isEmpty && (waistSlim != 0 || chestSize != 0 || shoulderWidth != 0 || armSlim != 0)
    }
}
