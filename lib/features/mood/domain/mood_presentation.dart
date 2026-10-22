/// The emoji/label pair shown for a given mood score (1-10), shared
/// between [LoveMeterScreen]'s mood logger and today-summary cards.
/// Extracted from the screen's `_getMoodEmoji`/`_getMoodLabel` (Migration
/// audit item 6) into pure, testable functions.
String moodEmojiFor(double score) {
  if (score <= 2) return '😢';
  if (score <= 4) return '😕';
  if (score <= 6) return '🙂';
  if (score <= 8) return '😊';
  return '😍';
}

String moodLabelFor(double score) {
  if (score <= 2) return 'Sad / Low energy';
  if (score <= 4) return 'A bit down / Tired';
  if (score <= 6) return 'Good / Content';
  if (score <= 8) return 'Happy / Positive';
  return 'Amazing / In Love!';
}
