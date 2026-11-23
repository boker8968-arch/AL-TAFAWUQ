import 'package:al_tafawuq/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('home screen renders Arabic learning sections', (tester) async {
    await tester.pumpWidget(const AlTafawuqApp());

    expect(find.text('منصة التفوق'), findsOneWidget);
    expect(find.text('ابدأ يومك بالإنجاز'), findsOneWidget);
    expect(find.text('المناهج'), findsOneWidget);
    expect(find.text('تعلم دون إنترنت'), findsOneWidget);
  });
}
