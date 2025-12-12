import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:world_math/firebase_options.dart';
import 'package:world_math/main.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  });
  testWidgets('App starts and displays splash screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const WorldMathApp());

    // Wait for all animations to complete.
    await tester.pumpAndSettle();

    // Verify that the subtitle is displayed.
    expect(find.text('현실감각 체험수학'), findsOneWidget);
  });
}
