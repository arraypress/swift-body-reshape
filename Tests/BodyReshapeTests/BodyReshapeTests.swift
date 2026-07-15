//
//  BodyReshapeTests.swift
//  BodyReshapeTests
//

import AVFoundation
import CoreGraphics
import CoreImage
import Foundation
import Testing
@testable import BodyReshape

@Suite("Body pose")
struct BodyReshapeTests {

    @Test("Pose frame round-trips through Codable")
    func roundTrip() throws {
        let f = BodyPoseFrame(time: 1.5, joints: [
            .neck: BodyPoint(x: 0.5, y: 0.25),
            .leftShoulder: BodyPoint(x: 0.35, y: 0.30),
            .rightShoulder: BodyPoint(x: 0.65, y: 0.30),
        ])
        let back = try JSONDecoder().decode(BodyPoseFrame.self, from: JSONEncoder().encode(f))
        #expect(back == f)
        #expect(back[.neck] == BodyPoint(x: 0.5, y: 0.25))
    }

    @Test("Track interpolates joints present at both ends, clamps")
    func interpolation() {
        let a = BodyPoseFrame(time: 0, joints: [.neck: BodyPoint(x: 0.4, y: 0.2)])
        let b = BodyPoseFrame(time: 2, joints: [.neck: BodyPoint(x: 0.6, y: 0.4)])
        let mid = BodyPoseTrack.sample(at: 1, keyframes: [a, b])!
        #expect(abs((mid[.neck]?.x ?? 0) - 0.5) < 1e-6)
        #expect(BodyPoseTrack.sample(at: -1, keyframes: [a, b])![.neck] == a[.neck])
        #expect(BodyPoseTrack.sample(at: 9, keyframes: [a, b])![.neck] == b[.neck])
    }

    // MARK: - Spike: skeleton grid on a real clip (opt-in)

    @Test("Write a pose-skeleton debug PNG",
          .enabled(if: ProcessInfo.processInfo.environment["BODY_RESHAPE_RENDER"] != nil))
    func skeletonGrid() async throws {
        let video = URL(fileURLWithPath: NSHomeDirectory() + "/Downloads/talking-head.mov")
        guard FileManager.default.fileExists(atPath: video.path) else { print("[skip]"); return }
        let keyframes = try await BodyPoseTracker.track(videoURL: video)
        print("POSE frames: \(keyframes.count)")
        guard let k = BodyPoseTrack.sample(at: 2.0, keyframes: keyframes) else { print("[skip] no pose"); return }
        print("JOINTS at t=2: \(k.joints.keys.map(\.rawValue).sorted())")

        let gen = AVAssetImageGenerator(asset: AVURLAsset(url: video))
        gen.appliesPreferredTrackTransform = true
        gen.requestedTimeToleranceBefore = .zero
        gen.requestedTimeToleranceAfter = .zero
        let cg = try gen.copyCGImage(at: CMTime(seconds: 2.0, preferredTimescale: 600), actualTime: nil)
        let W = cg.width, H = cg.height
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: W, height: H))

        func pt(_ p: BodyPoint) -> CGPoint { CGPoint(x: Double(p.x) * Double(W), y: (1 - Double(p.y)) * Double(H)) }
        func bone(_ a: BodyJointName, _ b: BodyJointName, _ c: CGColor) {
            guard let pa = k[a], let pb = k[b] else { return }
            ctx.setStrokeColor(c); ctx.setLineWidth(6)
            ctx.move(to: pt(pa)); ctx.addLine(to: pt(pb)); ctx.strokePath()
        }
        let boneC = CGColor(red: 0.2, green: 0.9, blue: 1, alpha: 1)
        let jointC = CGColor(red: 1, green: 0.85, blue: 0.2, alpha: 1)

        bone(.neck, .leftShoulder, boneC); bone(.neck, .rightShoulder, boneC)
        bone(.leftShoulder, .leftElbow, boneC); bone(.leftElbow, .leftWrist, boneC)
        bone(.rightShoulder, .rightElbow, boneC); bone(.rightElbow, .rightWrist, boneC)
        bone(.leftShoulder, .leftHip, boneC); bone(.rightShoulder, .rightHip, boneC)
        bone(.leftHip, .rightHip, boneC); bone(.neck, .root, boneC)

        for (_, p) in k.joints {
            let c = pt(p), r: CGFloat = 10
            ctx.setFillColor(jointC)
            ctx.fillEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
        }

        guard let out = ctx.makeImage() else { return }
        try CIContext().writePNGRepresentation(
            of: CIImage(cgImage: out),
            to: URL(fileURLWithPath: NSHomeDirectory() + "/Downloads/body_pose_skeleton.png"),
            format: .RGBA8, colorSpace: cs)
        print("WROTE ~/Downloads/body_pose_skeleton.png")
    }
}
