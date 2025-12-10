import 'package:flutter_test/flutter_test.dart';
import 'package:lego_brick_counter_app/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const LegoApp());
    expect(find.text('Lego Brick Counter'), findsWidgets);
    expect(find.text('Scan'), findsOneWidget);
    expect(find.text('Inventory'), findsOneWidget);
  });
}
