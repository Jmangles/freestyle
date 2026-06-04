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

**Left side controls:** Play/Pause, Restart, Step Back, Step Forward

**Right side controls:** Playback speed, Annotations *(stretch goal)*

## Video Upload Frontend
Show a screen where users can upload a video from their device and then trim and crop it if necessary.
All videos must be cropped to 9:16 for mobile users.
The video must be trimmed to a maximum of 10 seconds.

We will need to show a preview to users while they are in the process of uploading, reusing our existing video player as much as possible would be ideal.

When the user is happy with the result they can trigger an upload which will go to the CDN.
The name of the video should be in the format {trick_id}/forward.mp4.

If this trick is being uploaded as part of a user landing a trick, the format should be {trick_id}/{user_id}_forward.mp4.

## Video Upload Backend
Editors (users where `canEditTricks` is true on their `Profile`) will see an upload icon on the trick details screen. Tapping it opens a file picker to select a source video.

Encoding takes place client-side using `ffmpeg_kit_flutter` to avoid server costs. The package bundles FFmpeg natively for iOS and Android. The forward video is re-encoded to ensure consistent keyframe intervals, then uploaded to Bunny.net and the trick's `flags` field is updated to set bit 1.

`ffmpeg_kit_flutter` does not support Flutter web. If upload from a web build is ever required, both files would need to be prepared manually and uploaded via a separate tool.

Encoding command run client-side (using `-preset medium` rather than `-preset slow` to keep encode time reasonable on device):
```bash
# Forward (replace 8 and 15 with trim start/end in seconds)
ffmpeg -i input.mp4 -vf "trim=start=8:end=15,setpts=PTS-STARTPTS" -c:v libx264 -crf 18 -preset medium -r 60 -g 30 -keyint_min 30 -sc_threshold 0 -an trick_forward.mp4
```

## Implementation Phases
1. **Video player backend and local provider** — `VideoProvider` interface, `LocalVideoProvider`, player state logic, unit tests
2. **Training studio UI** — wire UI to backend, dev build entry point for easy access without a real trick
3. **Upload Studio UI** - create UI/UX for uploading videos to the CDN with optional trimming and cropping.
4. **Bunny CDN** — swap to `BunnyVideoProvider`, verify streaming and seeking behaviour with real hosted videos
5. **Upload backend** — client-side FFmpeg encoding, Bunny upload via Supabase Edge Function proxy, flag update
6. **Upload UI/UX** — editor upload icon on trick details screen, progress feedback
7. **AV1 support** — `codec_capability.dart` utility, `VideoProvider` AV1 URL methods, AV1 CDN files, offline storage constants for AV1 variants, codec selection wired into `_initPlayers()`; add `device_info_plus` dependency
8. **Annotations** *(stretch goal)* — data model, editor tooling, playback overlay

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
- **Codecs**: H.264 (baseline) and AV1 (where supported — see below)
- **Frame rate**: 60fps upload target, transcoded to 720p60 as a fallback
- **Keyframe interval**: Every 30 frames (0.5s) to enable fast seeking
### Flutter Player
The `media_kit` package (wraps libmpv) will be used as the video player. It supports:
- Precise seeking for frame-by-frame (seek by 1/60s per step)
- Playback speed control
- Full programmatic control over playback state
- Pre-buffering short clips for instant looping
### Codec Rationale
AV1 offers ~30–50% smaller files than H.264 at equivalent quality. It was previously ruled out due to inconsistent hardware decode support on mid-range Android devices (2020–2022). Two factors make AV1 viable now:

1. `media_kit`/libmpv bundles the `dav1d` software AV1 decoder on all platforms, so hardware decode is not required.
2. Videos are capped at 10 seconds — software AV1 decode via `dav1d` is CPU-affordable on any device from ~2018 at this clip length.

H.264 remains the baseline for older devices. H.265 is not pursued; AV1 is the better long-term path and is already broadly supported.

### AV1 Platform Support

The app serves AV1 where support is guaranteed and H.264 everywhere else. Detection is done once at player init via a `resolveVideoCodec()` utility (`lib/utils/codec_capability.dart`) that wraps `device_info_plus` on native platforms.

| Platform | Condition for AV1 | Notes |
|---|---|---|
| Web | Always | All modern browsers (Chrome 70+, Firefox 67+, Edge 79+) support AV1. A `canPlayType('video/mp4; codecs=av01')` JS interop guard confirms support. |
| Android | API 29+ (Android 10+) | `dav1d` handles SW decode for 10s clips; hardware AV1 decode available on most API 31+ devices. |
| iOS | iOS 14+ | `dav1d` handles SW decode; hardware AV1 decode available on A17 Pro+ (iPhone 15 Pro+). |
| macOS / Windows / Linux | Always | Desktop CPUs handle `dav1d` software decode easily for short clips. |

`initAv1Support()` is awaited in `main()` before `runApp`, so `av1Supported` is set before any video path is resolved. The filename getters in `offline_video_service.dart` read it directly, so `BunnyVideoProvider`, `OfflineVideoService`, and `TrainingStudioScreen` all pick up the right variant without any changes at their call sites.

```dart
// lib/utils/av1_support.dart
bool get av1Supported => _av1Supported;

Future<void> initAv1Support() async { ... }
```

```dart
// lib/video/offline_video_service.dart
String get kForwardVideo => 'forward${av1Supported ? '_av1' : ''}.mp4';
String get kForwardMobileVideo => 'forward_mobile${av1Supported ? '_av1' : ''}.mp4';
```

### CDN File Naming

Each trick has up to four video files on the CDN:

| File | Codec | Quality |
|---|---|---|
| `tricks/{trick_id}/forward.mp4` | H.264 | Full (existing) |
| `tricks/{trick_id}/forward_mobile.mp4` | H.264 | 720p (existing) |
| `tricks/{trick_id}/forward_av1.mp4` | AV1 | Full (new) |
| `tricks/{trick_id}/forward_mobile_av1.mp4` | AV1 | 720p (new) |

`VideoProvider` and `BunnyVideoProvider` require no changes — they already reference `kForwardVideo`/`kForwardMobileVideo`, which now return the codec-appropriate name automatically.

### AV1 Encoding Commands

Client-side encoding (via `ffmpeg_kit_flutter`) produces H.264 by default. AV1 variants are transcoded separately — either server-side or via a manual pipeline — since `ffmpeg_kit_flutter` bundle support for libaom-av1/libsvtav1 varies by build variant.

```bash
# AV1 full quality (libaom-av1 — widely available in ffmpeg builds)
ffmpeg -i input.mp4 \
  -vf "trim=start=8:end=15,setpts=PTS-STARTPTS" \
  -c:v libaom-av1 -crf 30 -cpu-used 4 -row-mt 1 \
  -r 60 -g 30 -keyint_min 30 -sc_threshold 0 -an \
  forward_av1.mp4

# AV1 mobile quality (720p)
ffmpeg -i input.mp4 \
  -vf "trim=start=8:end=15,setpts=PTS-STARTPTS,scale=-2:720" \
  -c:v libaom-av1 -crf 34 -cpu-used 4 -row-mt 1 \
  -r 60 -g 30 -keyint_min 30 -sc_threshold 0 -an \
  forward_mobile_av1.mp4
```

SVT-AV1 (`libsvtav1 -preset 5`) can substitute `libaom-av1` for significantly faster encodes at near-identical quality; use it if the ffmpeg build supports it.
