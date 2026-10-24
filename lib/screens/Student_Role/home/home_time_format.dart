/// Converts any 24-hour times inside a text label to 12-hour format.
///
/// "17:41 – 14:41"  ->  "5:41 PM – 2:41 PM"
/// "09:00"          ->  "9:00 AM"
/// "5:41 PM"        ->  unchanged (already 12-hour)
/// Blank or unrecognised text is returned unchanged, so it can never crash.
String formatTimeLabel12h(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return text;

  // Matches HH:mm or HH:mm:ss that is NOT already followed by AM/PM.
  final pattern = RegExp(r'\b(\d{1,2}):(\d{2})(?::\d{2})?(?!\s*[AaPp][Mm])\b');

  return text.replaceAllMapped(pattern, (match) {
    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);

    if (hour == null || minute == null || hour > 23 || minute > 59) {
      return match.group(0)!;
    }

    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    return '$hour12:${match.group(2)} $period';
  });
}
