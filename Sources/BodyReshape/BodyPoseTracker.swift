//
//  BodyPoseTracker.swift
//  BodyReshape
//
//  Created by David Sherlock on 2026.
//

import AVFoundation
import CoreGraphics
import Foundation
import Vision

/// Follows the most-confident person's body pose through a video and returns a
/// smoothed joint track for the reshape warps. On-device Vision throughout;
/// samples ~4 fps and interpolates between.
public enum BodyPoseTracker {

    private static let jointMap: [BodyJointName: VNHumanBodyPoseObservation.JointName] = [
        .neck: .neck, .root: .root,
        .leftShoulder: .leftShoulder, .rightShoulder: .rightShoulder,
        .leftElbow: .leftElbow, .rightElbow: .rightElbow,
        .leftWrist: .leftWrist, .rightWrist: .rightWrist,
        .leftHip: .leftHip, .rightHip: .rightHip,
    ]

    /// Samples the video, detects the strongest body pose per sample, and
    /// returns a lightly-smoothed track. Empty when no body is found.
    public static func track(videoURL: URL, fps: Double = 4, minConfidence: Float = 0.2) async throws -> [BodyPoseFrame] {
        let asset = AVURLAsset(url: videoURL)
        let duration = try await asset.load(.duration).seconds
        guard duration > 0 else { return [] }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 640, height: 640)
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.12, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.12, preferredTimescale: 600)

        let step = 1.0 / max(1, fps)
        let times = stride(from: 0.1, to: duration, by: step)
            .map { CMTime(seconds: $0, preferredTimescale: 600) }

        var samples: [BodyPoseFrame] = []
        for await result in generator.images(for: times) {
            guard let frame = try? result.image else { continue }
            let request = VNDetectHumanBodyPoseRequest()
            let handler = VNImageRequestHandler(cgImage: frame)
            try? handler.perform([request])
            guard let obs = strongest(request.results ?? []),
                  let points = try? obs.recognizedPoints(.all) else { continue }

            var joints: [BodyJointName: BodyPoint] = [:]
            for (name, vn) in jointMap {
                guard let p = points[vn], p.confidence >= minConfidence else { continue }
                // Vision points are normalized, bottom-left origin → flip Y.
                joints[name] = BodyPoint(x: p.location.x, y: 1 - p.location.y)
            }
            guard !joints.isEmpty else { continue }
            samples.append(BodyPoseFrame(time: result.requestedTime.seconds, joints: joints))
        }
        guard !samples.isEmpty else { return [] }
        return smoothed(samples)
    }

    /// The observation with the highest summed joint confidence.
    private static func strongest(_ results: [VNHumanBodyPoseObservation]) -> VNHumanBodyPoseObservation? {
        results.max { a, b in confidenceSum(a) < confidenceSum(b) }
    }

    private static func confidenceSum(_ obs: VNHumanBodyPoseObservation) -> Float {
        guard let pts = try? obs.recognizedPoints(.all) else { return 0 }
        return pts.values.reduce(0) { $0 + $1.confidence }
    }

    // MARK: - Smoothing (±2-sample moving average, per joint)

    private static func smoothed(_ s: [BodyPoseFrame]) -> [BodyPoseFrame] {
        guard s.count > 2 else { return s }
        var out: [BodyPoseFrame] = []
        for i in s.indices {
            let window = s[max(0, i - 2)...min(s.count - 1, i + 2)]
            var joints: [BodyJointName: BodyPoint] = [:]
            for name in BodyJointName.allCases {
                let pts = window.compactMap { $0[name] }
                guard !pts.isEmpty else { continue }
                let n = CGFloat(pts.count)
                joints[name] = BodyPoint(
                    x: pts.map(\.x).reduce(0, +) / n,
                    y: pts.map(\.y).reduce(0, +) / n
                )
            }
            out.append(BodyPoseFrame(time: s[i].time, joints: joints))
        }
        return out
    }
}
