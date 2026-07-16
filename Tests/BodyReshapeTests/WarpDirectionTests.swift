//
//  WarpDirectionTests.swift
//  BodyReshapeTests
//
//  Direction contract for the Metal warp: strength > 0 must MAGNIFY (bump),
//  strength < 0 must PINCH (slim). Pins the sign convention against the
//  Core Image fallback.
//

import CoreImage
import CoreGraphics
import Foundation
import Testing
@testable import BodyReshape

@Suite("BodyWarpDirection")
struct BodyWarpDirectionTests {

    private func rampValue(strength: Double, probeX: Int, size: Int = 64) -> Int? {
        let g = CIFilter(name: "CILinearGradient")!
        g.setValue(CIVector(x: 0, y: 0), forKey: "inputPoint0")
        g.setValue(CIVector(x: CGFloat(size), y: 0), forKey: "inputPoint1")
        g.setValue(CIColor.black, forKey: "inputColor0")
        g.setValue(CIColor.white, forKey: "inputColor1")
        let extent = CGRect(x: 0, y: 0, width: size, height: size)
        let ramp = g.outputImage!.cropped(to: extent)
        let c = CGPoint(x: CGFloat(size) / 2, y: CGFloat(size) / 2)
        guard let warped = BodyReshapeWarp.apply(
            ramp, extent: extent,
            waist: .init(center: c, radius: CGFloat(size) / 2 - 2, strength: strength),
            chest: nil, shoulderL: nil, shoulderR: nil, armL: nil, armR: nil
        ) else { return nil }
        var px = [UInt8](repeating: 0, count: size * size * 4)
        px.withUnsafeMutableBytes {
            CIContext().render(warped.cropped(to: extent), toBitmap: $0.baseAddress!, rowBytes: size * 4,
                               bounds: extent, format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
        }
        return Int(px[((size / 2) * size + probeX) * 4])
    }

    @Test("Positive strength magnifies, negative pinches")
    func directions() throws {
        guard BodyReshapeWarp.isAvailable else {
            Issue.record("Metal warp kernel failed to load")
            return
        }
        let probeX = 44
        let neutral = try #require(rampValue(strength: 0.0001, probeX: probeX))
        let pinched = try #require(rampValue(strength: -0.4, probeX: probeX))
        let bumped = try #require(rampValue(strength: 0.4, probeX: probeX))
        #expect(pinched > neutral + 3, "pinch must pull content inward (sampled \(pinched) vs \(neutral))")
        #expect(bumped < neutral - 3, "bump must magnify outward (sampled \(bumped) vs \(neutral))")
    }
}
