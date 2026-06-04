abstract class VideoProvider {
  Uri forwardUrl(int trickId);

  // Mobile-optimised variant (720p, CRF 26). Defaults to full quality so
  // LocalVideoProvider works without change.
  Uri forwardMobileUrl(int trickId) => forwardUrl(trickId);
}
