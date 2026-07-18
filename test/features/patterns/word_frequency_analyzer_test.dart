import 'package:flutter_test/flutter_test.dart';
import 'package:oneiro/src/features/patterns/domain/stopwords.dart';
import 'package:oneiro/src/features/patterns/domain/word_frequency_analyzer.dart';

void main() {
  const analyzer = WordFrequencyAnalyzer();

  group('stopword list', () {
    test('is self-consistent: lowercase, deduplicated, sane size', () {
      expect(englishStopwords.length, greaterThanOrEqualTo(140));
      for (final word in englishStopwords) {
        expect(word, word.toLowerCase());
        expect(word, isNot(contains(' ')));
      }
    });
  });

  group('tokenize', () {
    test('lowercases and splits on punctuation', () {
      expect(analyzer.tokenize('Flying past the Ocean, FLYING skyward!'), {
        'flying',
        'past',
        'ocean',
        'skyward',
      });
    });

    test('drops stopwords and short words', () {
      expect(analyzer.tokenize('I was in the dream and it felt so very odd'), {
        'odd',
      });
    });

    test('keeps hashtags as first-class tokens with their hash', () {
      expect(analyzer.tokenize('Chased by dogs #nightmare #Nightmare #lucid'), {
        'chased',
        'dogs',
        '#nightmare',
        '#lucid',
      });
    });

    test('hashtags bypass the stopword list', () {
      expect(analyzer.tokenize('#dream #the'), {'#dream', '#the'});
    });

    test('drops hashtags shorter than the minimum length', () {
      expect(analyzer.tokenize('#ab #abc ###'), {'#abc'});
    });

    test('is Unicode-aware: Tamil words survive intact', () {
      expect(analyzer.tokenize('கனவில் பறந்தேன் மீண்டும் கனவில்'), {
        'கனவில்',
        'பறந்தேன்',
        'மீண்டும்',
      });
    });

    test('handles apostrophes, digits and emoji as separators', () {
      expect(analyzer.tokenize("don't run 2 fast 🌙 running"), {
        'don',
        'run',
        'fast',
        'running',
      });
    });
  });

  group('analyze', () {
    test('counts occurrences and sorts by count then alphabetically', () {
      final result = analyzer.analyze([
        'ocean waves crashing on the ocean shore',
        'flying towards the ocean',
        'flying fish flying',
      ]);
      expect(result, const [
        WordFrequency('flying', 3),
        WordFrequency('ocean', 3),
        WordFrequency('crashing', 1),
        WordFrequency('fish', 1),
        WordFrequency('shore', 1),
        WordFrequency('waves', 1),
      ]);
    });

    test('empty input yields an empty list', () {
      expect(analyzer.analyze(const []), isEmpty);
      expect(analyzer.analyze(['the and or of to in']), isEmpty);
    });

    test('hashtag and plain word are counted separately', () {
      final result = analyzer.analyze(['ocean #ocean ocean']);
      expect(result, const [
        WordFrequency('ocean', 2),
        WordFrequency('#ocean', 1),
      ]);
    });
  });

  group('analyzeEntries', () {
    const entries = [
      (text: 'flying over rooftops', isLucid: true),
      (text: 'drowning in deep water', isLucid: false),
      (text: 'flying with whales', isLucid: true),
    ];

    test('all dreams by default', () {
      expect(analyzer.analyzeEntries(entries), const [
        WordFrequency('flying', 2),
        WordFrequency('deep', 1),
        WordFrequency('drowning', 1),
        WordFrequency('rooftops', 1),
        WordFrequency('water', 1),
        WordFrequency('whales', 1),
      ]);
    });

    test('lucidOnly restricts to lucid dreams', () {
      expect(analyzer.analyzeEntries(entries, lucidOnly: true), const [
        WordFrequency('flying', 2),
        WordFrequency('rooftops', 1),
        WordFrequency('whales', 1),
      ]);
    });
  });
}
