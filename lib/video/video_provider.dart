abstract class VideoProvider {
  Uri forwardUrl(int trickId);
  Uri reversedUrl(int trickId);

  // Mobile-optimised variants (720p, CRF 26). Defaults to full quality so
  // LocalVideoProvider works without change.
  Uri forwardMobileUrl(int trickId) => forwardUrl(trickId);
  Uri reversedMobileUrl(int trickId) => reversedUrl(trickId);
}
