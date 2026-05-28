// Playback and loop-detection timing constants for the video layer.

/// Debounce window for completed-event bursts from the media player.
const Duration kEofDebounce = Duration(milliseconds: 300);

/// Tolerance used to distinguish a false EOF from a real one.
/// If the player position is this far from the end when completed fires,
/// buffered frames remain — drive the buffer, don't loop.
const Duration kEofTolerance = Duration(seconds: 1);

/// The previous position must have been beyond this before a backward jump
/// is considered a potential loop rather than a normal scrub.
const Duration kJumpMinPrev = Duration(milliseconds: 500);

/// Once the looping player's position exceeds this after a seek-to-zero,
/// the loop flag is cleared and normal event handling resumes.
const Duration kLoopClearThreshold = Duration(milliseconds: 200);

/// Positions below this are treated as "at start" for EOF-loop detection.
const Duration kNearStartThreshold = Duration(milliseconds: 100);

/// MPV demuxer forward and backward cache limits (64 MB each).
const String kMpvCacheBytes = '67108864';

/// MPV network timeout in seconds.
const String kMpvNetworkTimeout = '20';

/// Default new-annotation end offset in milliseconds relative to its start.
const int kAnnotationDefaultDurationMs = 2000;
