import 'package:flutter_front_end/model/rules/listing_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ListingRules.parsePrice', () {
    test('"." and "," separate thousands, so a price in pesos never turns into a few pesos', () {
      expect(ListingRules.parsePrice('45000'), 45000);
      expect(ListingRules.parsePrice('45.000'), 45000);
      expect(ListingRules.parsePrice('45,000'), 45000);
      expect(ListingRules.parsePrice('1.250.000'), 1250000);
      expect(ListingRules.parsePrice('1,250,000'), 1250000);
      expect(ListingRules.parsePrice('  35000 '), 35000);
    });

    test('decimals and odd groupings are not a price', () {
      for (final text in ['45.5', '45,50', '35500,5', '45..000', '4.5000', '.000', '45.', 'abc', '', '-5000', '1e5', 'NaN', 'Infinity']) {
        expect(ListingRules.parsePrice(text), isNull, reason: text);
      }
    });
  });

  group('ListingRules.validatePrice', () {
    test('accepts 1.000 to 50.000.000 pesos', () {
      for (final text in ['1000', '1.000', '35000', '50000000', '50.000.000']) {
        expect(ListingRules.validatePrice(text), isNull, reason: text);
      }
    });

    test('refuses a price outside the range with a clear message', () {
      const message = 'The price must be between \$1.000 and \$50.000.000 COP.';
      for (final text in ['0', '1', '999', '50000001', '50.000.001', '99999999999999999999999']) {
        expect(ListingRules.validatePrice(text), message, reason: text);
      }
    });

    test('says what is wrong with an empty or badly written price', () {
      expect(ListingRules.validatePrice('   '), 'Enter a price.');
      expect(ListingRules.validatePrice(null), 'Enter a price.');
      expect(ListingRules.validatePrice('45.5'), 'Enter the price in whole pesos, like 45000 or 45.000.');
      expect(ListingRules.validatePrice('abc'), 'Enter the price in whole pesos, like 45000 or 45.000.');
    });
  });

  group('ListingRules title', () {
    test('is trimmed and its inner whitespace collapsed', () {
      expect(ListingRules.normalizeTitle('  Organic    Chemistry \t Book '), 'Organic Chemistry Book');
    });

    test('needs 3 to 60 characters, none of them a control character', () {
      expect(ListingRules.maxTitleLength, 60);
      expect(ListingRules.validateTitle('Cal'), isNull);
      expect(ListingRules.validateTitle('a' * 60), isNull);
      expect(ListingRules.validateTitle('   '), 'Add a title.');
      expect(ListingRules.validateTitle('ab'), 'The title needs 3 to 60 characters.');
      expect(ListingRules.validateTitle('   a   '), 'The title needs 3 to 60 characters.');
      expect(ListingRules.validateTitle('a' * 61), 'The title needs 3 to 60 characters.');
      expect(ListingRules.validateTitle('Arduino\x00UNO'), 'The title has characters that are not allowed.');
      expect(ListingRules.validateTitle('Arduino\u{200B}UNO'), 'The title has characters that are not allowed.');
    });
  });

  group('ListingRules title emojis', () {
    test('are refused with a clear message', () {
      for (final title in ['Arduino UNO 🔧', '📚 Calculus', 'Libro ❤️', 'Mesa 🇨🇴', 'Silla 👍🏽']) {
        expect(ListingRules.validateTitle(title), "The title can't contain emojis.", reason: title);
      }
    });

    test('accents, digits and normal symbols are fine', () {
      for (final title in ['Cálculo Diferencial 2ª ed.', 'Silla #3 (casi nueva) - \$20.000', 'Física I & II']) {
        expect(ListingRules.validateTitle(title), isNull, reason: title);
      }
    });
  });

  group('ListingRules description', () {
    test('is trimmed but keeps its line breaks', () {
      expect(ListingRules.normalizeDescription('  Barely used.\nWith cable.  '), 'Barely used.\nWith cable.');
    });

    test('needs 10 to 330 characters, none of them a control character', () {
      expect(ListingRules.maxDescriptionLength, 330);
      expect(ListingRules.validateDescription('Barely used'), isNull);
      expect(ListingRules.validateDescription('Line one\nline two'), isNull);
      expect(ListingRules.validateDescription('a' * 330), isNull);
      expect(ListingRules.validateDescription('   '), 'Add a description.');
      expect(ListingRules.validateDescription('Works'), 'The description needs 10 to 330 characters.');
      expect(ListingRules.validateDescription('          x '), 'The description needs 10 to 330 characters.');
      expect(ListingRules.validateDescription('a' * 331), 'The description needs 10 to 330 characters.');
      expect(ListingRules.validateDescription('Barely used\x07 with cable'), 'The description has characters that are not allowed.');
    });
  });
}
