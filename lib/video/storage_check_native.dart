import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

// Calls statvfs(2) via dart:ffi and returns available bytes for non-root users,
// or null if the call fails or the platform/ABI is unsupported.
int? statvfsFreeBytes(String path) {
  try {
    final lib = DynamicLibrary.process();
    final cMalloc = lib.lookupFunction<
        Pointer<Uint8> Function(IntPtr),
        Pointer<Uint8> Function(int)>('malloc');
    final cFree = lib.lookupFunction<
        Void Function(Pointer<Uint8>),
        void Function(Pointer<Uint8>)>('free');
    final statvfs = lib.lookupFunction<
        Int32 Function(Pointer<Uint8>, Pointer<Uint8>),
        int Function(Pointer<Uint8>, Pointer<Uint8>)>('statvfs');

    final pathBytes = [...utf8.encode(path), 0];
    final pathPtr = cMalloc(pathBytes.length);
    for (var i = 0; i < pathBytes.length; i++) {
      pathPtr[i] = pathBytes[i];
    }

    const bufSize = 512; // Darwin arm64 struct is ~176 B today; 512 gives headroom for future SDK changes
    final buf = cMalloc(bufSize);
    for (var i = 0; i < bufSize; i++) {
      buf[i] = 0;
    }

    try {
      if (statvfs(pathPtr, buf) != 0) return null;
      // Plausibility cap: a wrong struct layout can produce a large positive
      // value rather than a negative one (which the caller already guards).
      // Anything above 8 TiB is treated as indeterminate rather than trusted.
      const int k8TiB = 8 * 1024 * 1024 * 1024 * 1024;
      if (Platform.isIOS) {
        // Darwin arm64 statvfs layout — offsets derived from sys/mount.h
        // (#pragma pack(4)). If Apple changes the struct layout in a future SDK
        // this silently returns a wrong byte count; the failure mode is safe
        // (caller treats null as "cannot determine" → allow) but a wrong
        // positive value could incorrectly block an operation. Re-verify these
        // offsets against sys/mount.h when bumping the minimum iOS version.
        // f_frsize (unsigned long, 8 B) at offset 8; f_bavail (uint32_t) at offset 24.
        final freeBytes = _readU64LE(buf, 8) * _readU32LE(buf, 24);
        return freeBytes > k8TiB ? null : freeBytes;
      }
      // Linux 64-bit (Android arm64/x86_64) — offsets from sys/statvfs.h.
      // Re-verify against the NDK header when upgrading the minimum API level.
      // f_frsize (unsigned long, 8 B) at offset 8; f_bavail (uint64_t) at offset 32.
      // 32-bit Android not handled — null causes the caller to allow the operation.
      if (sizeOf<IntPtr>() != 8) return null;
      final freeBytes = _readU64LE(buf, 8) * _readU64LE(buf, 32);
      return freeBytes > k8TiB ? null : freeBytes;
    } finally {
      cFree(pathPtr);
      cFree(buf);
    }
  } catch (_) {
    return null;
  }
}

int _readU64LE(Pointer<Uint8> buf, int offset) {
  var v = 0;
  for (var i = 7; i >= 0; i--) {
    v = (v << 8) | buf[offset + i];
  }
  return v;
}

int _readU32LE(Pointer<Uint8> buf, int offset) =>
    buf[offset] |
    (buf[offset + 1] << 8) |
    (buf[offset + 2] << 16) |
    (buf[offset + 3] << 24);
