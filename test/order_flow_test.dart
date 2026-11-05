import 'package:dealer_app/app/app.dart';
import 'package:dealer_app/core/storage/local_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(overrides: [localStoreProvider.overrideWithValue(LocalStore(prefs))], child: const DealerApp()),
  );
  await _settle(tester);
}

/// Waits out the fake repositories' latency. pumpAndSettle alone can't, because
/// timers don't count as pending frames.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<void> _tapText(WidgetTester tester, String text) async {
  final finder = find.text(text).first;
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await _settle(tester);
}

Future<void> _signIn(WidgetTester tester, String phone) async {
  await tester.enterText(find.byType(TextFormField), phone);
  await _tapText(tester, 'Send OTP');
  await tester.enterText(find.byType(TextField), '123456');
  await _tapText(tester, 'Verify and continue');
}

void main() {
  testWidgets('a wrong OTP is rejected', (tester) async {
    await _pumpApp(tester);
    await tester.enterText(find.byType(TextFormField), '9876543210');
    await _tapText(tester, 'Send OTP');
    await tester.enterText(find.byType(TextField), '000000');
    await _tapText(tester, 'Verify and continue');
    expect(find.textContaining('Incorrect OTP'), findsOneWidget);
    expect(find.text('Enter OTP'), findsWidgets);
    await tester.pump(const Duration(minutes: 1));
  });

  testWidgets('the demo dealer can sign in with a password, and a wrong one is rejected', (tester) async {
    await _pumpApp(tester);
    await _tapText(tester, 'Sign in with password');
    await tester.enterText(find.byType(TextFormField).at(0), '9876543210');
    await tester.enterText(find.byType(TextFormField).at(1), 'wrong-password');
    await _tapText(tester, 'Sign in');
    expect(find.textContaining('Incorrect mobile number'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(1), 'Demo@1234');
    await _tapText(tester, 'Sign in');
    expect(find.text('Hello, Demo Dealer'), findsOneWidget);
  });

  testWidgets('a new number goes to registration', (tester) async {
    await _pumpApp(tester);
    await _signIn(tester, '9000000001');
    expect(find.text('Business registration'), findsOneWidget);
  });

  testWidgets('the demo dealer can order on credit and see it in orders and payments', (tester) async {
    await _pumpApp(tester);
    await _signIn(tester, '9876543210');
    expect(find.text('Hello, Demo Dealer'), findsOneWidget);
    expect(find.text('₹10,313.20'), findsOneWidget);

    await _tapText(tester, 'Place a new order');
    await tester.tap(find.text('Add').first);
    await tester.pump();
    await _tapText(tester, '5 kg bag');
    expect(find.text('Volume pricing'), findsOneWidget);
    await tester.pageBack();
    await _settle(tester);

    await tester.tap(find.textContaining('View cart'));
    await _settle(tester);
    expect(find.text('Cart'), findsOneWidget);
    expect(find.textContaining('minimum order value'), findsOneWidget);

    await tester.tap(find.byTooltip('Increase quantity'));
    await tester.pump();
    await tester.tap(find.byTooltip('Increase quantity'));
    await _settle(tester);
    await tester.tap(find.textContaining('Checkout'));
    await _settle(tester);

    await _tapText(tester, '6 PM - 9 PM');
    await _tapText(tester, 'Credit account');
    await tester.tap(find.textContaining('Place order'));
    await _settle(tester);
    expect(find.text('Order placed'), findsOneWidget);

    await _tapText(tester, 'Track order');
    expect(find.text('Order details'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Cancel order'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Cancel order'), findsOneWidget);

    await _tapText(tester, 'Cancel order');
    await _tapText(tester, 'Ordered by mistake');
    expect(find.text('Order cancelled'), findsWidgets);
    // The screen keeps its scroll position, so go back up to the status.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
    await _settle(tester);
    expect(find.text('Cancelled'), findsWidgets);
    await tester.pump(const Duration(seconds: 5));
  });
}
