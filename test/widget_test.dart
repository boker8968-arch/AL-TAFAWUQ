import 'package:al_tafawuq/features/home/presentation/home_page.dart';
import 'package:al_tafawuq/features/student/data/student_pin_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Student PIN format', () {
    test('accepts exactly four ASCII digits', () {
      expect(StudentPinService.isValidPinFormat('1234'), isTrue);
      expect(StudentPinService.isValidPinFormat('0000'), isTrue);
    });

    test('rejects wrong length and non-ASCII digits', () {
      expect(StudentPinService.isValidPinFormat('123'), isFalse);
      expect(StudentPinService.isValidPinFormat('12345'), isFalse);
      expect(StudentPinService.isValidPinFormat('12a4'), isFalse);
      expect(StudentPinService.isValidPinFormat('١٢٣٤'), isFalse);
      expect(StudentPinService.isValidPinFormat(''), isFalse);
    });
  });

  testWidgets('home screen renders branded Arabic learning sections',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: HomePage(),
        ),
      ),
    );

    expect(find.text('التفوق'), findsOneWidget);
    expect(find.byTooltip('حول منصة التفوق'), findsOneWidget);
    expect(find.text('ابدأ يومك بالإنجاز'), findsOneWidget);
    expect(find.text('المناهج'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('تعلم دون إنترنت'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('تعلم دون إنترنت'), findsOneWidget);
  });
}
