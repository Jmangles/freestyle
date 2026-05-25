# Custom Video Player
For the application we want to include a custom video player that plays videos we host on our own CDN somewhere.
This video player will be tailored towards learning tricks rather than normal playback.
## Features
These features will be necessary to help users learn tricks as easily as possible:
- Minimal perceptible load time
- Forward or backward playback
- Playback speed controls
- Frame-by-Frame controls
- Annotations *(stretch goal)*
- Minimal buffering when seeking forward or backward
- No Buffering to Loop
### Load Times
Videos should not need to load for a long period of time otherwise users will get frustrated. A good streaming setup is necessary.
### Forward or Backward Playback
Users will want to watch the videos forward or backward and should be able to do so instantly without triggering any buffering.
### Playback Speed Controls
Users will want to slow down footage to analyze exactly what is happening.
### Frame-By-Frame controls
Stepping through complex parts of tricks frame-by-frame will be helpful for users.
### Annotations *(stretch goal)*
Editors should be able to place annotations that correspond to a timestamp in the video and are visible for whatever time window they choose.
### Minimal Buffering While Seeking
Since users will be jumping around the timeline a lot we want this to be fast.
### No Buffering to Loop
The video should be able to loop instantly with no buffering.
## Navigation
If a trick has a video for this system there should be an option on the trick page to open a "training studio" screen where all of this functionality is available.

The trick model uses bit 1 (value `2`) of its `flags` field to indicate a training video is available:
```dart
bool get hasTrainingVideo => (flags & 2) != 0;
```
This follows the existing pattern where bit 0 (value `1`) denotes `isCore`.

## Training Studio UI
The training studio is a full screen with the video occupying the main area and a control bar below.

**Left side controls:** Play/Pause, Restart, Direction toggle (forward/reverse), Step Back, Step Forward

**Right side controls:** Playback speed, Annotations *(stretch goal)*

## Video Upload
Editors (users where `canEditTricks` is true on their `Profile`) will see an upload icon on the trick details screen. Tapping it opens a file picker to select a source video.

Encoding takes place client-side using `ffmpeg_kit_flutter` to avoid server costs. The package bundles FFmpeg natively for iOS and Android. Two files are produced:
1. The forward video (re-encoded to ensure consistent keyframe intervals)
2. The reversed copy

Both are uploaded to Bunny.net and the trick's `flags` field is updated to set bit 1.

`ffmpeg_kit_flutter` does not support Flutter web. If upload from a web build is ever required, both files would need to be prepared manually and uploaded via a separate tool.

Encoding commands run client-side (using `-preset medium` rather than `-preset slow` to keep encode time reasonable on device):
```bash
# Forward
ffmpeg -i input.mp4 -c:v libx264 -crf 18 -preset medium -r 60 -g 30 -keyint_min 30 -sc_threshold 0 -an trick_forward.mp4

# Reversed
ffmpeg -i input.mp4 -vf reverse -c:v libx264 -crf 18 -preset medium -r 60 -g 30 -keyint_min 30 -sc_threshold 0 -an trick_reversed.mp4
```

## Implementation Phases
1. **Video player backend and local provider** — `VideoProvider` interface, `LocalVideoProvider`, player state logic, unit tests
2. **Training studio UI** — wire UI to backend, dev build entry point for easy access without a real trick
3. **Bunny CDN** — swap to `BunnyVideoProvider`, verify streaming and seeking behaviour with real hosted videos
4. **Upload backend** — client-side FFmpeg encoding, Bunny upload via Supabase Edge Function proxy, flag update
5. **Upload UI/UX** — editor upload icon on trick details screen, progress feedback
6. **Annotations** *(stretch goal)* — data model, editor tooling, playback overlay

## Legacy Videos
This should not affect the existing video system.
## Development Approach
### Video Provider Interface
The video player will depend on an abstract `VideoProvider` interface rather than hardcoding Bunny.net. This allows swapping the source without touching player logic.

Planned implementations:
- `BunnyVideoProvider` — production, resolves trick IDs to Bunny.net CDN URLs
- `LocalVideoProvider` — development/testing, resolves to a local HTTP server running on the dev machine

### Local Test Videos
Test videos are generated from a source clip using FFmpeg and placed in `test/fixtures/videos/` manually. This directory is never registered in `pubspec.yaml` so Flutter never bundles it in any build.

To manually test the player during development, serve the directory over HTTP:

```bash
# Option A — Node.js (recommended, handles CORS automatically)
npx serve test/fixtures/videos --cors --listen 8080

# Option B — Python (run from project root)
python test/serve_local_videos.py
```

A CORS-enabled server is required for Chrome (Flutter web) builds. Different ports on localhost count as different origins, and Chrome will block video requests from a server that doesn't send `Access-Control-Allow-Origin` headers. Mobile emulators are not affected by this.

`LocalVideoProvider` resolves URLs as:
- iOS Simulator / Chrome: `http://localhost:8080/`
- Android Emulator: `http://10.0.2.2:8080/`
- Physical device: host machine's LAN IP (same WiFi required)

### Test Suite
Unit tests only. The `VideoProvider` will be mocked in all player logic tests. Tests will cover provider resolution, player state (speed, direction, seek position), and frame stepping logic.

## Technical Decisions
### CDN
Videos will be hosted on Bunny.net. It offers strong global CDN performance at low cost (~$0.01/GB storage, ~$0.01–$0.05/GB egress) with simple HTTP delivery and no proprietary lock-in.
### Video Encoding
- **Codec**: H.264
- **Frame rate**: 60fps upload target, transcoded to 720p60 as a fallback
- **Keyframe interval**: Every 30 frames (0.5s) to enable fast seeking
- **Reversed copy**: A reversed version of every video is pre-generated at upload time to support instant backward playback without re-encoding at runtime
### Backward Playback Implementation
Standard H.264 uses inter-frame prediction, making real-time reverse playback impractical. Instead, each video will have a pre-encoded reversed copy stored alongside it. When the user switches to reverse playback, the player switches to the reversed file at the mirrored timestamp:

```
reversed_position = total_duration - current_position
```

For example, if a video is 12s long and the user is at 4s, the reversed file seeks to 8s. The same formula applies when switching back to forward. The player state must track `totalDuration` from the forward file as the canonical source of truth, since both files have the same duration.
### Flutter Player
The `media_kit` package (wraps libmpv) will be used as the video player. It supports:
- Precise seeking for frame-by-frame (seek by 1/60s per step)
- Playback speed control
- Full programmatic control over playback state
- Pre-buffering short clips for instant looping
### Codec Rationale
AV1 was considered for its better compression (~30–50% smaller than H.264) but was ruled out due to inconsistent hardware decode support on mid-range Android devices (2020–2022). H.265 is the natural next step if file size becomes a concern, with H.264 remaining the baseline for maximum device compatibility. AV1 should be reconsidered when hardware support matures.
