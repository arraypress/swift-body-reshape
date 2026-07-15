//
//  BodyPose.swift
//  BodyReshape
//
//  Created by David Sherlock on 2026.
//

import CoreGraphics
import Foundation

/// A normalized point: `x`,`y` in `0…1` from the top-left of the frame.
public struct BodyPoint: Codable, Equatable, Hashable, Sendable {
    public var x: CGFloat
    public var y: CGFloat
    public init(x: CGFloat, y: CGFloat) { self.x = x; self.y = y }
}

/// The body joints we track, by name. Only what body reshaping needs — the
/// torso and arms (legs are usually out of frame for a talking head).
public enum BodyJointName: String, Codable, CaseIterable, Sendable {
    case neck, root
    case leftShoulder, rightShoulder
    case leftElbow, rightElbow
    case leftWrist, rightWrist
    case leftHip, rightHip
}

/// One sampled body pose on the source timeline. `joints` holds only the joints
/// detected above the confidence floor, so callers must handle missing ones.
public struct BodyPoseFrame: Codable, Equatable, Sendable {

    /// Source time in seconds.
    public var time: TimeInterval
    /// Detected joints (normalized, top-left origin), keyed by name.
    public var joints: [BodyJointName: BodyPoint]

    public init(time: TimeInterval, joints: [BodyJointName: BodyPoint]) {
        self.time = time
        self.joints = joints
    }

    public subscript(_ name: BodyJointName) -> BodyPoint? { joints[name] }
}

/// Linear interpolation over the pose track — clamped, per-joint (a joint only
/// interpolates across frames where both ends detected it).
public enum BodyPoseTrack {

    public static func sample(at time: TimeInterval, keyframes: [BodyPoseFrame]) -> BodyPoseFrame? {
        guard let first = keyframes.first, let last = keyframes.last else { return nil }
        if time <= first.time { return first }
        if time >= last.time { return last }
        for (from, to) in zip(keyframes, keyframes.dropFirst()) where time < to.time {
            let span = max(0.0001, to.time - from.time)
            let t = CGFloat((time - from.time) / span)
            var joints: [BodyJointName: BodyPoint] = [:]
            for name in BodyJointName.allCases {
                guard let a = from[name], let b = to[name] else { continue }
                joints[name] = BodyPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
            }
            return BodyPoseFrame(time: time, joints: joints)
        }
        return last
    }
}
