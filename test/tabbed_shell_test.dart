import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:practice/core/theme/app_theme.dart';
import 'package:practice/shared/shell/tabbed_shell.dart';

/// The shell's contract: tab stacks survive switching, the bar is never
/// unmounted, and detail screens push into the tab rather than over the shell.
///
/// These run on the non-iOS path (tests report as linux/macos), so the bar is
/// the Flutter one — but the navigator behaviour under test is identical.
/// Stateful so a test can prove the tab survives a switch rather than being
/// rebuilt from scratch.
class _TabOneRoot extends StatefulWidget {
  const _TabOneRoot();

  @override
  State<_TabOneRoot> createState() => _TabOneRootState();
}

class _TabOneRootState extends State<_TabOneRoot> {
  int _count = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('tab-one-root'),
            Text('count: $_count'),
            Text('root-inset: ${MediaQuery.paddingOf(context).bottom}'),
            ElevatedButton(
              onPressed: () => setState(() => _count++),
              child: const Text('bump'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => Scaffold(
                    body: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('tab-one-detail'),
                          Text(
                            'detail-inset: '
                            '${MediaQuery.paddingOf(context).bottom}',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              child: const Text('open detail'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reads the bottom inset a route reported through its debug label.
double _insetFrom(WidgetTester tester, String prefix) {
  final finder = find.textContaining(prefix);
  expect(finder, findsOneWidget, reason: 'no widget carrying "$prefix"');
  final text = tester.widget<Text>(finder).data!;
  return double.parse(text.substring(prefix.length));
}

/// Counts how many times its screen is *created*, which is when a real tab
/// would build its cubit and fetch.
class _CountsCreations extends StatefulWidget {
  const _CountsCreations({required this.onCreate, required this.label});

  final VoidCallback onCreate;
  final String label;

  @override
  State<_CountsCreations> createState() => _CountsCreationsState();
}

class _CountsCreationsState extends State<_CountsCreations> {
  @override
  void initState() {
    super.initState();
    widget.onCreate();
  }

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text(widget.label)));
}

void main() {
  Widget harness() => MaterialApp(
    theme: AppTheme.light,
    home: TabbedShell(
      tabs: [
        ShellTab(
          label: 'One',
          sfSymbol: 'circle',
          icon: Icons.circle_outlined,
          selectedIcon: Icons.circle,
          builder: (context) => const _TabOneRoot(),
        ),
        ShellTab(
          label: 'Two',
          sfSymbol: 'square',
          icon: Icons.square_outlined,
          selectedIcon: Icons.square,
          builder: (_) =>
              const Scaffold(body: Center(child: Text('tab-two-root'))),
        ),
      ],
    ),
  );

  testWidgets('renders the first tab and its bar', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.text('tab-one-root'), findsOneWidget);
    expect(find.text('One'), findsOneWidget);
    expect(find.text('Two'), findsOneWidget);
  });

  testWidgets('switching tabs keeps both navigators mounted', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Two'));
    await tester.pumpAndSettle();

    // IndexedStack keeps the inactive tab in the tree, just not visible —
    // that is what preserves each tab's stack.
    expect(find.text('tab-two-root'), findsOneWidget);
    expect(
      find.text('tab-one-root', skipOffstage: false),
      findsOneWidget,
      reason: 'tab one must stay mounted so its stack survives',
    );
  });

  testWidgets('a detail screen pushes inside the tab, bar stays in the tree', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('open detail'));
    await tester.pumpAndSettle();

    expect(find.text('tab-one-detail'), findsOneWidget);
    // The bar slides away but is never removed — the whole point of the
    // architecture. Finding it offstage proves it was not unmounted.
    expect(find.text('One', skipOffstage: false), findsOneWidget);
  });

  testWidgets('the bar is not tappable while a detail screen is open', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('open detail'));
    await tester.pumpAndSettle();

    // The bar slid away and is wrapped in IgnorePointer, so this tap is
    // swallowed. Consequence: tabs cannot be switched from a detail screen,
    // and "re-tap the active tab to pop to root" can never fire — the user
    // must use back or the screen's own control.
    await tester.tap(find.text('Two'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('tab-one-detail'), findsOneWidget);
    expect(find.text('tab-two-root'), findsNothing);
  });

  testWidgets('switching tabs preserves each tab\'s state', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('bump'));
    await tester.tap(find.text('bump'));
    await tester.pumpAndSettle();
    expect(find.text('count: 2'), findsOneWidget);

    await tester.tap(find.text('Two'));
    await tester.pumpAndSettle();
    expect(find.text('tab-two-root'), findsOneWidget);

    await tester.tap(find.text('One'));
    await tester.pumpAndSettle();

    expect(
      find.text('count: 2'),
      findsOneWidget,
      reason: 'IndexedStack must keep the tab alive across a switch',
    );
  });

  testWidgets('back pops the tab stack before leaving the shell', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('open detail'));
    await tester.pumpAndSettle();

    final popped = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(popped, isTrue);
    expect(find.text('tab-one-detail'), findsNothing);
    expect(find.text('tab-one-root'), findsOneWidget);
  });

  testWidgets('back from a secondary tab returns to the first tab', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Two'));
    await tester.pumpAndSettle();
    expect(find.text('tab-two-root'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('tab-one-root'), findsOneWidget);
  });

  testWidgets('a pushed screen does not reserve room for the hidden bar', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    // The tab root sits under the bar, so it is padded to clear it.
    final rootInset = _insetFrom(tester, 'root-inset: ');
    expect(rootInset, greaterThan(0));

    await tester.tap(find.text('open detail'));
    await tester.pumpAndSettle();

    // The detail screen slides the bar away, so it must not keep the bar's
    // padding — that showed up as dead space beneath the add-to-cart bar.
    final detailInset = _insetFrom(tester, 'detail-inset: ');
    expect(detailInset, lessThan(rootInset));
    expect(
      detailInset,
      tester.view.padding.bottom / tester.view.devicePixelRatio,
    );
  });

  group('tabs are built on first sight', () {
    testWidgets('an unvisited tab never runs its builder', (tester) async {
      var oneBuilt = 0;
      var twoBuilt = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: TabbedShell(
            tabs: [
              ShellTab(
                label: 'One',
                sfSymbol: 'circle',
                icon: Icons.circle_outlined,
                selectedIcon: Icons.circle,
                builder: (_) =>
                    _CountsCreations(onCreate: () => oneBuilt++, label: 'one'),
              ),
              ShellTab(
                label: 'Two',
                sfSymbol: 'square',
                icon: Icons.square_outlined,
                selectedIcon: Icons.square,
                builder: (_) =>
                    _CountsCreations(onCreate: () => twoBuilt++, label: 'two'),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The whole point: every admin tab fetches on build, so a tab nobody has
      // opened must not be constructed. `IndexedStack` builds all of its
      // children, which is what made landing on the shell fire four requests.
      expect(oneBuilt, 1);
      expect(twoBuilt, 0);

      await tester.tap(find.text('Two'));
      await tester.pumpAndSettle();
      expect(twoBuilt, 1);

      // ...and going back does not rebuild it, so its state and its already
      // loaded data survive.
      await tester.tap(find.text('One'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Two'));
      await tester.pumpAndSettle();
      expect(twoBuilt, 1);
      expect(oneBuilt, 1);
    });
  });
}
