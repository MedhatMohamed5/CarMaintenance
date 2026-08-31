import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_care/core/localization/app_localizations.dart';
import 'package:vehicle_care/core/theme/app_theme.dart';
import 'package:vehicle_care/core/widgets/coach_mark.dart';

/// A screen with two tagged targets: one near the top, one pinned to the
/// bottom, so the bubble has to be placed below the first and above the second.
class _Host extends StatelessWidget {
  const _Host({required this.cardKey, required this.barKey});

  final GlobalKey cardKey;
  final GlobalKey barKey;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        const SizedBox(height: 60),
        Container(key: cardKey, height: 120, color: Colors.blue),
        const Spacer(),
        Container(key: barKey, height: 64, color: Colors.green),
      ],
    ),
  );
}

void main() {
  // Unknown l10n keys fall back to the key itself, so step copy is findable by
  // name without pinning the test to a real translation.
  CoachStep step(GlobalKey key, String name) => CoachStep(
    targetKey: key,
    titleKey: '$name-title',
    bodyKey: '$name-body',
    icon: Icons.circle,
    color: Colors.cyan,
  );

  /// Mounts [home] and returns a context under the app.
  ///
  /// The extra settle is not ceremony: `AppLocalizations.delegate.load` is
  /// `async`, so `Localizations` resolves a frame after the first pump and
  /// nothing below it exists until then.
  Future<BuildContext> pumpHost(WidgetTester tester, Widget home) async {
    late BuildContext hostContext;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [AppLocalizations.delegate],
        home: Builder(
          builder: (context) {
            hostContext = context;
            return home;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    return hostContext;
  }

  testWidgets('walks its steps and dismisses on the last one', (tester) async {
    final cardKey = GlobalKey();
    final barKey = GlobalKey();
    final host = await pumpHost(
      tester,
      _Host(cardKey: cardKey, barKey: barKey),
    );

    showCoachMarks(
      host,
      steps: [step(cardKey, 'first'), step(barKey, 'second')],
    );
    await tester.pumpAndSettle();

    expect(find.text('first-title'), findsOneWidget);
    expect(find.text('first-body'), findsOneWidget);
    // Nothing to go back to on the opening step.
    expect(find.text('Back'), findsNothing);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('first-title'), findsNothing);
    expect(find.text('second-title'), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);
    // The last step offers no way to skip what is already over.
    expect(find.text('Skip'), findsNothing);

    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();

    expect(find.text('second-title'), findsNothing);
  });

  testWidgets('Back returns to the previous step', (tester) async {
    final cardKey = GlobalKey();
    final barKey = GlobalKey();
    final host = await pumpHost(
      tester,
      _Host(cardKey: cardKey, barKey: barKey),
    );

    showCoachMarks(
      host,
      steps: [step(cardKey, 'first'), step(barKey, 'second')],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();

    expect(find.text('first-title'), findsOneWidget);
  });

  testWidgets('Skip ends the tour without walking the rest', (tester) async {
    final cardKey = GlobalKey();
    final barKey = GlobalKey();
    final host = await pumpHost(
      tester,
      _Host(cardKey: cardKey, barKey: barKey),
    );

    showCoachMarks(
      host,
      steps: [step(cardKey, 'first'), step(barKey, 'second')],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.text('first-title'), findsNothing);
    expect(find.text('second-title'), findsNothing);
  });

  testWidgets('drops steps whose target is not mounted', (tester) async {
    final cardKey = GlobalKey();
    final barKey = GlobalKey();
    final host = await pumpHost(
      tester,
      _Host(cardKey: cardKey, barKey: barKey),
    );

    showCoachMarks(
      host,
      steps: [
        step(GlobalKey(), 'missing'),
        step(cardKey, 'first'),
        step(barKey, 'second'),
      ],
    );
    await tester.pumpAndSettle();

    // The absent step is gone, and with it the position it would have held:
    // the tour opens on the first target that actually exists.
    expect(find.text('missing-title'), findsNothing);
    expect(find.text('first-title'), findsOneWidget);
  });

  testWidgets('a tour with nothing to point at never opens', (tester) async {
    final host = await pumpHost(tester, const Scaffold(body: SizedBox()));

    await showCoachMarks(host, steps: [step(GlobalKey(), 'nowhere')]);
    await tester.pumpAndSettle();

    expect(find.text('nowhere-title'), findsNothing);
  });

  testWidgets('the system back button ends the tour', (tester) async {
    final cardKey = GlobalKey();
    final barKey = GlobalKey();
    final host = await pumpHost(
      tester,
      _Host(cardKey: cardKey, barKey: barKey),
    );

    showCoachMarks(host, steps: [step(cardKey, 'first')]);
    await tester.pumpAndSettle();
    expect(find.text('first-title'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('first-title'), findsNothing);
  });
}
