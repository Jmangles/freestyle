/// Returns [value] trimmed, or null if it is null or blank after trimming.
String? trimToNull(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
