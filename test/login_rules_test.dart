import 'package:flutter_front_end/model/rules/login_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LoginRules.containsEmoji', () {
    test('detects emojis of every kind', () {
      const emojis = ['😀', '🎉', '👍🏽', '❤️', '⭐', '✅', '⌚', '🇨🇴', '👨‍👩‍👧', '1️⃣', '🧑‍💻', '☀', '✈'];
      for (final e in emojis) {
        expect(LoginRules.containsEmoji('abc${e}def'), isTrue, reason: e);
      }
    });

    test('ordinary text, accents and symbols are not emojis', () {
      const text = ['ana@uniandes.edu.co', 'Contraseña-Ñandú_2026', r'p@ss!#$%&*()+=', 'ü é ñ ç', '日本語', '    '];
      for (final t in text) {
        expect(LoginRules.containsEmoji(t), isFalse, reason: t);
      }
    });
  });

  group('LoginRules.validateEmail', () {
    test('accepts well-formed addresses, any domain', () {
      const good = [
        'ana@uniandes.edu.co',
        'a@b.co',
        'first.last+tag@sub.example.com',
        "o'brien@example.org",
        'x_y-z@my-domain.io',
        '  padded@example.com  ',
        'UPPER@EXAMPLE.COM',
      ];
      for (final e in good) {
        expect(LoginRules.validateEmail(e), isNull, reason: e);
      }
    });

    test('empty or blank', () {
      expect(LoginRules.validateEmail(null), 'Enter your email.');
      expect(LoginRules.validateEmail(''), 'Enter your email.');
      expect(LoginRules.validateEmail('   '), 'Enter your email.');
    });

    test('rejects emojis with their own message', () {
      expect(LoginRules.validateEmail('ana😀@uniandes.edu.co'), "The email can't contain emojis.");
      expect(LoginRules.validateEmail('ana@uniandes.edu.co🎉'), "The email can't contain emojis.");
    });

    test('rejects malformed addresses', () {
      const bad = [
        'plainaddress',
        '@uniandes.edu.co',
        'ana@',
        'ana@uniandes',
        'ana@uniandes.',
        'ana@.co',
        'ana@@uniandes.edu.co',
        'a na@uniandes.edu.co',
        'ana@uni andes.edu.co',
        'ana@uniandes..co',
        'ana@-uniandes.co',
        'ana@uniandes.c',
        'ana@uniandes.123',
        'ana,perez@uniandes.edu.co',
      ];
      for (final e in bad) {
        expect(LoginRules.validateEmail(e), 'Enter a valid email, like name@domain.com.', reason: e);
      }
    });

    test('rejects absurdly long addresses', () {
      expect(LoginRules.validateEmail('${'a' * 250}@b.co'), isNotNull);
    });
  });

  group('LoginRules.validatePassword', () {
    test('accepts 8 to 72 characters, spaces inside included', () {
      expect(LoginRules.validatePassword('12345678'), isNull);
      expect(LoginRules.validatePassword('correct horse battery'), isNull);
      expect(LoginRules.validatePassword('a' * 72), isNull);
    });

    test('empty is rejected', () {
      expect(LoginRules.validatePassword(null), 'Enter your password.');
      expect(LoginRules.validatePassword(''), 'Enter your password.');
    });

    test('only spaces is rejected, however long', () {
      expect(LoginRules.validatePassword(' '), "The password can't be only spaces.");
      expect(LoginRules.validatePassword('          '), "The password can't be only spaces.");
      expect(LoginRules.validatePassword('\t\n  '), "The password can't be only spaces.");
    });

    test('emojis are rejected', () {
      expect(LoginRules.validatePassword('password😀1'), "The password can't contain emojis.");
    });

    test('length limits follow sign-up', () {
      expect(LoginRules.validatePassword('1234567'), 'Use at least 8 characters.');
      expect(LoginRules.validatePassword('a' * 73), 'Use at most 72 characters.');
    });
  });

  test('normalizeEmail trims and lower-cases', () {
    expect(LoginRules.normalizeEmail('  Ana@Uniandes.EDU.co \n'), 'ana@uniandes.edu.co');
  });
}
