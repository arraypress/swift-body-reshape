# swift-body-reshape

On-device, license-clean **body reshaping** for photos and video — Vision body
pose tracking + Core Image warps (slim waist, chest, arms). No generative model.

**Status: spike.** The pose tracker + a skeleton-grid debug overlay are in;
the reshape warps come once the pose is validated on unobstructed torso footage.
A face-focused close-up (mic/cup occluding the torso) tracks shoulders/neck well
but the arms and lower torso are unreliable — reshape needs a half/full-body shot.

- `BodyPose` / `BodyPoseFrame` / `BodyPoseTrack` — Codable model + interpolation.
- `BodyPoseTracker` — VNDetectHumanBodyPose, strongest person, ~4 fps, smoothed.
- Debug: `BODY_RESHAPE_RENDER=1 swift test` writes `~/Downloads/body_pose_skeleton.png`.

## Requirements

macOS 26 / iOS 26, Swift 6.2.
