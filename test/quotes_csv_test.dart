import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stoic_quotes/quotes_page.dart';

void main() {
  group('parseQuotesCsv', () {
    test('keeps quote and author of the same row together', () {
      const csvText = '"First quote.","Seneca"\n"Second quote.","Epictetus"\n';

      final quotes = parseQuotesCsv(csvText);

      expect(quotes, [
        {'quote': 'First quote.', 'author': 'Seneca'},
        {'quote': 'Second quote.', 'author': 'Epictetus'},
      ]);
    });

    test('does not split on semicolons inside a quote', () {
      const csvText = '"Act; then speak.","Epictetus"\n';

      final quotes = parseQuotesCsv(csvText);

      expect(quotes.single['quote'], 'Act; then speak.');
    });

    test('skips rows that have no author column', () {
      const csvText = '"Only a quote"\n"Full row.","Seneca"\n';

      expect(parseQuotesCsv(csvText), hasLength(1));
    });

    test('bundled quote file parses into non empty quotes and authors', () {
      final csvText = File('lib/assets/quotes_list.csv').readAsStringSync();

      final quotes = parseQuotesCsv(csvText);

      expect(quotes, hasLength(64));
      for (final quote in quotes) {
        expect(quote['quote'], isNotEmpty);
        expect(quote['author'], isNotEmpty);
      }
    });
  });
}
