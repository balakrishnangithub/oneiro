import 'stopwords.dart';

/// One recurring theme word and how often it appeared.
class WordFrequency {
  const WordFrequency(this.word, this.count);

  /// Lowercased token; hashtags keep their leading `#`.
  final String word;

  /// Number of occurrences across all analyzed texts.
  final int count;

  @override
  bool operator ==(Object other) =>
      other is WordFrequency && other.word == word && other.count == count;

  @override
  int get hashCode => Object.hash(word, count);

  @override
  String toString() => 'WordFrequency($word, $count)';
}

/// A piece of dream text plus its lucidity flag, for filtered analysis.
typedef DreamText = ({String text, bool isLucid});

/// Counts recurring words and hashtags across dream texts.
///
/// Pure Dart: no Flutter, no database. Tokenization is Unicode-aware, so
/// non-Latin scripts (e.g. Tamil) work as first-class words. A token is a
/// maximal run of Unicode letters plus `#`; a token starting with `#` is a
/// hashtag and is kept verbatim (hashtags bypass the stopword list because
/// the dreamer tagged them deliberately).
class WordFrequencyAnalyzer {
  const WordFrequencyAnalyzer();

  /// Words shorter than this (after lowercasing, hashtags excluded) are
  /// dropped. `#` does not count towards a hashtag's length.
  static const int minWordLength = 3;

  /// Letters and combining marks (e.g. Tamil vowel signs) form tokens.
  static final RegExp _separator = RegExp(
    r'[^\p{L}\p{M}#]+',
    unicode: true,
  );
  static final RegExp _leadingHashes = RegExp('^#+');

  /// Extracts the normalized, deduplicated tokens of a single [text].
  Set<String> tokenize(String text) {
    final tokens = <String>{};
    for (final raw in text.toLowerCase().split(_separator)) {
      if (raw.isEmpty) continue;
      final isHashtag = raw.startsWith('#');
      final bare = isHashtag ? raw.replaceFirst(_leadingHashes, '') : raw;
      if (bare.length < minWordLength) continue;
      if (!isHashtag && englishStopwords.contains(bare)) continue;
      // A run of only `#` characters leaves an empty bare token.
      if (bare.isEmpty) continue;
      tokens.add(isHashtag ? '#$bare' : bare);
    }
    return tokens;
  }

  /// Counts token occurrences across [texts], most frequent first
  /// (ties broken alphabetically).
  List<WordFrequency> analyze(Iterable<String> texts) {
    final counts = <String, int>{};
    for (final text in texts) {
      for (final token in text.toLowerCase().split(_separator)) {
        if (token.isEmpty) continue;
        final isHashtag = token.startsWith('#');
        final bare = isHashtag ? token.replaceFirst(_leadingHashes, '') : token;
        if (bare.length < minWordLength || bare.isEmpty) continue;
        if (!isHashtag && englishStopwords.contains(bare)) continue;
        final word = isHashtag ? '#$bare' : bare;
        counts[word] = (counts[word] ?? 0) + 1;
      }
    }
    final result = [
      for (final entry in counts.entries) WordFrequency(entry.key, entry.value),
    ];
    result.sort((a, b) {
      final byCount = b.count.compareTo(a.count);
      return byCount != 0 ? byCount : a.word.compareTo(b.word);
    });
    return result;
  }

  /// Counts theme words over dream [entries], optionally restricted to
  /// lucid dreams only.
  List<WordFrequency> analyzeEntries(
    Iterable<DreamText> entries, {
    bool lucidOnly = false,
  }) {
    return analyze(
      entries
          .where((entry) => !lucidOnly || entry.isLucid)
          .map((entry) => entry.text),
    );
  }
}
