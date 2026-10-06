import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sweldo/core/storage/local_store.dart';
import 'package:sweldo/features/tour/tour_controller.dart';
import 'package:sweldo/features/tour/tour_overlay.dart';

import '../../helpers/fonts.dart';

const _steps = [
  TourStep(title: 'Welcome', body: 'Hello.'),
  TourStep(target: 'here', title: 'This button', body: 'It does a thing.'),
  TourStep(target: 'missing', title: 'Not on screen', body: 'Skipped.'),
  TourStep(title: 'Done', body: 'Bye.'),
];

void main() {
  setUpAll(loadAppFonts);

  test('moves through steps and remembers it was seen', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await LocalStore.open();
    final tour = TourController(steps: _steps, store: store);
    expect(tour.hasBeenSeen, isFalse);
    tour.start();
    expect(tour.isOpen, isTrue);
    tour.next();
    tour.next();
    expect(tour.index, 2);
    tour.back();
    expect(tour.index, 1);
    expect(tour.direction, -1);
    tour.finish();
    expect(tour.isOpen, isFalse);
    expect(tour.hasBeenSeen, isTrue);
  });

  testWidgets('spotlights targets and skips ones that are not on the page',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final tour = TourController(steps: _steps);
    addTearDown(tour.dispose);
    final router = GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Stack(
          children: [
            Scaffold(
              body: Center(
                child: TourTarget(
                  id: 'here',
                  child: ElevatedButton(onPressed: () {}, child: const Text('Target')),
                ),
              ),
            ),
            const Positioned.fill(child: TourOverlay(currentPath: '/')),
          ],
        ),
      ),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      TourScope(controller: tour, child: MaterialApp.router(routerConfig: router)),
    );

    tour.start();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Welcome'), findsOneWidget);
    expect(find.text('1 of 4'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('This button'), findsOneWidget);

    // The missing target is skipped straight to the last step.
    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Done'), findsWidgets);
    expect(tour.index, 3);

    await tester.tap(find.text('Done').last);
    await tester.pump();
    expect(tour.isOpen, isFalse);
    expect(tester.takeException(), isNull);
  });
}
