import 'package:http/http.dart' as http;

const _speedTestUrl = 'https://freestyledb.b-cdn.net/speedtest.bin';

// Threshold below which we serve mobile-quality video (in Mbps).
const kMobileQualityThresholdMbps = 2.0;

/// Downloads the speed-test asset from the CDN and returns the estimated
/// connection speed in Mbps, or null if the request fails.
/// Downloads the speed-test asset from the CDN and returns the estimated
/// connection speed in Mbps, or null if the request fails.
/// [onError] receives the error string in debug builds.
Future<double?> estimateConnectionSpeedMbps({void Function(String)? onError}) async {
  try {
    final uri = Uri.parse(
      '$_speedTestUrl?t=${DateTime.now().millisecondsSinceEpoch}',
    );
    final stopwatch = Stopwatch()..start();
    final response = await http.get(uri);
    stopwatch.stop();

    if (response.statusCode != 200) {
      onError?.call('HTTP ${response.statusCode}');
      return null;
    }

    final elapsedMs = stopwatch.elapsedMilliseconds;
    if (elapsedMs == 0) return null;

    final bits = response.bodyBytes.length * 8;
    return bits / (elapsedMs * 1000); // Mbps
  } catch (e) {
    onError?.call(e.toString());
    return null;
  }
}
