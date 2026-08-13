import 'dart:io' show Platform;

import 'package:cupertino_native/cupertino_native.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/animations/motion.dart';
import '../../core/animations/page_transitions.dart';
import '../../core/haptics/app_haptics.dart';
import '../widgets/app_nav_bar.dart';

/// One tab in a [TabbedShell].
class ShellTab {
  const ShellTab({
    required this.label,
    required this.sfSymbol,
    required this.icon,
    required this.selectedIcon,
    required this.builder,
  });

  final String label;

  /// SF Symbol name, used by the native iOS bar.
  final String sfSymbol;

  /// Material icons, used by the Flutter bar on every other platform.
  final IconData icon;
  final IconData selectedIcon;

  final WidgetBuilder builder;
}

/// A tabbed shell whose navigation bar is never unmounted.
///
/// On iOS the bar is a genuine `UITabBar` rendered through a platform view
/// (`CNTabBar`). Platform views are expensive to compose, and removing one
/// from the tree makes iOS re-composite it on return — which shows as a white
/// flash. Everything about this widget exists to keep that from happening:
///
///  * Each tab owns a nested [Navigator], and they all live in an
///    [IndexedStack], so switching tabs preserves each tab's stack.
///  * Detail screens push into their **tab's** navigator, not the root one,
///    so a pushed route never covers the bar.
///  * The bar sits in a [Positioned] layered over the stack and is never
///    removed. On detail screens it slides off-screen instead.
class TabbedShell extends StatefulWidget {
  const TabbedShell({
    super.key,
    required this.tabs,
    this.initialIndex = 0,
    this.tint,
  });

  final List<ShellTab> tabs;
  final int initialIndex;

  /// Selected-item colour. Defaults to the theme's primary.
  final Color? tint;

  /// Switches the enclosing shell to [index].
  ///
  /// For the case where a screen's own content should send the user to a
  /// *different tab* rather than push a route — an empty orders list offering
  /// the menu, say. Pushing the menu into the Orders tab would leave the user
  /// browsing dishes with "Orders" lit in the bar.
  ///
  /// Silently does nothing outside a [TabbedShell], so a screen can be used
  /// standalone or in a test without needing one.
  static void selectTab(BuildContext context, int index) =>
      context.findAncestorStateOfType<_TabbedShellState>()?.selectTab(index);

  @override
  State<TabbedShell> createState() => _TabbedShellState();
}

class _TabbedShellState extends State<TabbedShell> {
  late int _currentIndex = widget.initialIndex;
  late final List<GlobalKey<NavigatorState>> _navigatorKeys = List.generate(
    widget.tabs.length,
    (_) => GlobalKey<NavigatorState>(),
  );

  /// False while the active tab has a detail screen open.
  bool _showBar = true;
  bool _refreshScheduled = false;

  NavigatorState? get _activeNavigator =>
      _navigatorKeys[_currentIndex].currentState;

  /// Recomputed after the frame settles — `canPop()` is only meaningful once
  /// the push or pop has actually been applied to the navigator.
  void _scheduleBarVisibilityRefresh() {
    if (_refreshScheduled) return;
    _refreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshScheduled = false;
      if (!mounted) return;
      final shouldShow = !(_activeNavigator?.canPop() ?? false);
      if (shouldShow != _showBar) setState(() => _showBar = shouldShow);
    });
  }

  /// Programmatic tab change — see [TabbedShell.selectTab].
  ///
  /// Deliberately not [_onTabSelected]: that one plays a selection haptic and
  /// pops the tab to root on a re-tap, both of which belong to a finger on the
  /// bar rather than to a button inside a screen.
  void selectTab(int index) {
    if (index == _currentIndex || index < 0 || index >= widget.tabs.length) {
      return;
    }
    setState(() => _currentIndex = index);
    _scheduleBarVisibilityRefresh();
  }

  void _onTabSelected(int index) {
    if (index == _currentIndex) {
      // Standard iOS behaviour: re-tapping the active tab returns it to root.
      _activeNavigator?.popUntil((route) => route.isFirst);
      _scheduleBarVisibilityRefresh();
      return;
    }
    AppHaptics.selection();
    setState(() => _currentIndex = index);
    _scheduleBarVisibilityRefresh();
  }

  Future<void> _handleBack() async {
    final navigator = _activeNavigator;
    if (navigator?.canPop() ?? false) {
      navigator!.pop();
      _scheduleBarVisibilityRefresh();
      return;
    }
    if (_currentIndex != 0) {
      setState(() => _currentIndex = 0);
      _scheduleBarVisibilityRefresh();
      return;
    }
    // Nothing left to unwind — let the OS take it.
    await SystemNavigator.pop();
  }

  /// UIKit's tab bar content height, for the native bar on iOS.
  ///
  /// The Material bar is taller — M3 specifies 64 of content against UIKit's 50 —
  /// so the two can no longer share one number. Reporting the Material height on
  /// iOS would leave 14pt of dead space under every screen.
  static const double _nativeBarHeight = 50;

  /// Height the bar occupies, so screens inside a tab can clear it.
  ///
  /// The remaining difference is what each does without a home indicator: the
  /// Material bar adds M3's own bottom padding, the native one is already inset.
  double _barExtent(double bottomInset) =>
      (_useNativeBar ? _nativeBarHeight : AppNavBar.barHeight) +
      (bottomInset > 0
          ? bottomInset
          : (_useNativeBar
                ? 0.0
                : AppNavBar.bottomPaddingWithoutInset));

  Widget _tabNavigator(int index, double barExtent) {
    return Navigator(
      key: _navigatorKeys[index],
      observers: [_BarVisibilityObserver(_scheduleBarVisibilityRefresh)],
      // Report the bar as bottom padding so the tab's screen clears it via its
      // existing `MediaQuery.paddingOf(context).bottom`, without having to know
      // a magic number.
      //
      // Only the tab's *root* route gets this. The override used to wrap the
      // whole navigator, which meant every pushed screen reserved room for a
      // bar that isn't there — a detail screen slides the bar away, so the
      // padding became dead space under whatever sat at the bottom, most
      // visibly the add-to-cart bar on a dish.
      onGenerateRoute: (settings) => AppPageRoute<void>(
        settings: settings,
        builder: (context) {
          final media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(
              padding: media.padding.copyWith(bottom: barExtent),
            ),
            child: widget.tabs[index].builder(context),
          );
        },
      ),
    );
  }

  bool get _useNativeBar => !kIsWeb && Platform.isIOS;

  @override
  Widget build(BuildContext context) {
    final motion = context.motion;
    final tint = widget.tint ?? Theme.of(context).colorScheme.primary;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        // The bar floats over the content rather than displacing it, so the
        // blur has something to blur.
        extendBody: true,
        body: Stack(
          children: [
            Positioned.fill(
              child: IndexedStack(
                index: _currentIndex,
                children: [
                  for (var i = 0; i < widget.tabs.length; i++)
                    _tabNavigator(i, _barExtent(bottomInset)),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedSlide(
                // Slid away, never removed. 1.6 clears the bar and its
                // shadow even on the tallest safe-area inset.
                offset: _showBar ? Offset.zero : const Offset(0, 1.6),
                duration: motion.move(Motion.base),
                curve: motion.enter,
                child: IgnorePointer(
                  ignoring: !_showBar,
                  child: _buildNavBar(tint, bottomInset),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavBar(Color tint, double bottomInset) {
    if (_useNativeBar) {
      return Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: CNTabBar(
          currentIndex: _currentIndex,
          onTap: _onTabSelected,
          tint: tint,
          items: [
            for (final tab in widget.tabs)
              CNTabBarItem(label: tab.label, icon: CNSymbol(tab.sfSymbol)),
          ],
        ),
      );
    }

    return AppNavBar(
      currentIndex: _currentIndex,
      onTap: _onTabSelected,
      tint: tint,
      items: [
        for (final tab in widget.tabs)
          AppNavItem(
            label: tab.label,
            icon: tab.icon,
            selectedIcon: tab.selectedIcon,
          ),
      ],
    );
  }
}

/// Tells the shell to re-check whether the active tab has a detail screen
/// open. Any push or pop can change the answer.
class _BarVisibilityObserver extends NavigatorObserver {
  _BarVisibilityObserver(this.onChanged);

  final VoidCallback onChanged;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      onChanged();

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      onChanged();

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      onChanged();

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      onChanged();
}
