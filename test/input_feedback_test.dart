import 'package:flutter/material.dart';
import 'package:flutter_front_end/app/theme/app_theme.dart';
import 'package:flutter_front_end/model/rules/client_id.dart';
import 'package:flutter_front_end/model/rules/input_rules.dart';
import 'package:flutter_front_end/model/rules/listing_rules.dart';
import 'package:flutter_front_end/model/rules/registration_rules.dart';
import 'package:flutter_front_end/view/widgets/common_widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isUuid', () {
    test('accepts what the server hands out and refuses placeholders', () {
      expect(isUuid(newClientId()), isTrue);
      expect(isUuid('11111111-1111-4111-8111-111111111111'), isTrue);
      for (final bad in [null, '', 'guest', 'temp-abc', 'm1', '1111', ' 11111111-1111-4111-8111-111111111111']) {
        expect(isUuid(bad), isFalse, reason: '$bad');
      }
    });

    test('is as strict as the server: version 1-5 and variant 8, 9, a or b (RFC 4122)', () {
      // 32 hex digits that PostgreSQL stores but class-validator refuses.
      for (final bad in [
        '8e1365a6-fa6e-ca75-96ab-db7e5ec1de34', // version c
        '311d1af1-52b9-01f4-ab49-5f216e8666da', // version 0
        '2d7074e1-ff8d-8f67-e0e7-1eeb784376e7', // version 8 and variant e
        '00000000-0000-4000-c000-000000000000', // variant c
        '00000000-0000-6000-8000-000000000000', // version 6
      ]) {
        expect(isUuid(bad), isFalse, reason: bad);
      }
      for (final good in [
        '00000000-0000-1000-8000-000000000000',
        '00000000-0000-5000-b000-000000000000',
        'ABCDEF01-2345-4678-A9BC-DEF012345678', // upper case
      ]) {
        expect(isUuid(good), isTrue, reason: good);
      }
    });
  });

  group('InputRules.counterLevel', () {
    test('is normal, then amber from 85 % of the limit, then full at the limit', () {
      expect(InputRules.counterLevel(0, 50), CounterLevel.normal);
      expect(InputRules.counterLevel(42, 50), CounterLevel.normal); // 84 %
      expect(InputRules.counterLevel(43, 50), CounterLevel.warning); // 86 %
      expect(InputRules.counterLevel(49, 50), CounterLevel.warning);
      expect(InputRules.counterLevel(50, 50), CounterLevel.full);
      expect(InputRules.counterLevel(51, 50), CounterLevel.full);
    });
  });

  group('limits', () {
    test('the major has at most 50 characters', () {
      expect(RegistrationRules.maxMajorLength, 50);
      expect(RegistrationRules.validateMajor('a' * 50), isNull);
      expect(RegistrationRules.validateMajor('a' * 51), 'Your major is too long (at most 50 characters).');
    });

    test('the course code is optional and has at most 20 characters', () {
      expect(ListingRules.validateCourseCode(''), isNull);
      expect(ListingRules.validateCourseCode('MATE 1203'), isNull);
      expect(ListingRules.validateCourseCode('C' * 21), isNotNull);
    });
  });

  group('CounterLabel colours', () {
    Future<Color?> colourOf(WidgetTester tester, int length, int max) async {
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData.light(),
        home: Scaffold(body: CounterLabel(length: length, max: max)),
      ));
      return tester.widget<Text>(find.text('$length/$max')).style?.color;
    }

    testWidgets('grey, then amber at 85 %, then red at 100 %', (tester) async {
      expect(await colourOf(tester, 10, 60), AppColors.lightTextMuted);
      expect(await colourOf(tester, 51, 60), AppColors.lightWarning);
      expect(await colourOf(tester, 60, 60), AppColors.lightError);
    });

    testWidgets('can stay hidden until 80 % of the limit', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: CounterLabel(length: 700, max: 2000, showFrom: 0.8)),
      ));
      expect(find.text('700/2000'), findsNothing);
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: CounterLabel(length: 1600, max: 2000, showFrom: 0.8)),
      ));
      expect(find.text('1600/2000'), findsOneWidget);
    });
  });

  group('FieldFeedback', () {
    late TextEditingController ctrl;
    setUp(() => ctrl = TextEditingController());
    tearDown(() => ctrl.dispose());

    testWidgets('says nothing until the field is edited, then warns while typing', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FieldFeedback(
            controller: ctrl,
            max: 10,
            validate: (t) => t.length < 3 ? 'Too short.' : null,
            hintKey: const Key('hint'),
          ),
        ),
      ));
      expect(find.byKey(const Key('hint')), findsNothing, reason: 'untouched field');

      ctrl.selection = const TextSelection.collapsed(offset: 0); // focus and cursor moves are not typing
      await tester.pump();
      expect(find.byKey(const Key('hint')), findsNothing);

      ctrl.text = 'a';
      await tester.pump();
      expect(find.text('Too short.'), findsOneWidget);

      ctrl.text = 'abc';
      await tester.pump();
      expect(find.byKey(const Key('hint')), findsNothing);
    });

    testWidgets('warns when an emoji is removed and clears it with the next plain edit', (tester) async {
      final blocker = EmojiBlocker();
      addTearDown(blocker.dispose);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Column(children: [
            TextField(controller: ctrl, inputFormatters: [blocker]),
            FieldFeedback(controller: ctrl, emojiBlocker: blocker, emojiNoticeKey: const Key('emoji')),
          ]),
        ),
      ));

      await tester.enterText(find.byType(TextField), 'Ana 😀');
      await tester.pump();
      expect(ctrl.text, 'Ana ');
      expect(find.byKey(const Key('emoji')), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Ana G');
      await tester.pump();
      expect(find.byKey(const Key('emoji')), findsNothing);
    });
  });
}
