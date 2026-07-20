import '../models/legacy_import.dart';

// The legacy app was browser-only, so there is never anything to import
// outside the web build.
class LegacyImportService {
  LegacyImportService._();

  static Future<LegacyScan?> scan() async => null;
  static Future<LegacyImportResult> import(LegacyScan _) async =>
      const LegacyImportResult(
          written: 0, skippedNotHigher: 0, untransferable: 0);
  static Future<bool> isDone() async => true;
  static Future<void> markPromptSeen() async {}
  static Future<bool> promptSeen() async => true;
}
