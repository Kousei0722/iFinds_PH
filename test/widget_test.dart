import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/main.dart';

void main() {
  testWidgets('shows the iFinds PH welcome screen', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Welcome to iFinds PH'), findsOneWidget);
    expect(find.text('ONLINE\nSHOPPING'), findsOneWidget);
  });
}
