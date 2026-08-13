import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'core/animations/motion.dart';
import 'core/config/app_config.dart';
import 'core/network/api_client.dart';
import 'core/network/connectivity_service.dart';
import 'core/network/token_store.dart';
import 'features/auth/data/api_auth_repository.dart';
import 'features/admin/data/api_admin_contact_repository.dart';
import 'features/admin/data/api_admin_menu_repository.dart';
import 'features/admin/data/api_admin_order_repository.dart';
import 'features/admin/domain/admin_contact_repository.dart';
import 'features/admin/domain/admin_order_repository.dart';
import 'features/admin/domain/admin_menu_repository.dart';
import 'features/contact/data/api_contact_repository.dart';
import 'features/contact/domain/contact_repository.dart';
import 'features/menu/data/api_menu_repository.dart';
import 'features/menu/domain/menu_repository.dart';
import 'features/orders/data/api_order_repository.dart';
import 'features/orders/data/demo_order_repository.dart';
import 'features/orders/domain/order_repository.dart';
import 'core/animations/page_transitions.dart';
import 'core/theme/app_spacing.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_cubit.dart';
import 'features/auth/login_screen.dart';
import 'features/cart/cart_cubit.dart';
import 'features/shell/admin_shell.dart';
import 'features/shell/customer_shell.dart';
import 'features/welcome/presentation/welcome_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Reads `.env` before anything can ask for a URL. Deliberately awaited: a
  // half-configured client is harder to diagnose than a clear startup failure.
  await AppConfig.load();

  // Composed here rather than behind a service locator: the graph is four
  // objects deep, and one readable wiring site beats indirection that hides
  // which implementation is in play.
  final tokens = TokenStore();
  await tokens.restore();

  final client = ApiClient(tokens: tokens, connectivity: ConnectivityService());
  final auth = AuthCubit(
    repository: ApiAuthRepository(client: client, tokens: tokens),
  );

  // Closes the loop: when a refresh finally fails, the app returns to sign-in
  // instead of leaving the user on a screen that will never load again.
  client.onSessionExpired = auth.signOut;

  // Not awaited — the app opens on the splash and swaps to the right shell when
  // the answer arrives, rather than holding a blank screen on a slow network.
  auth.restore();

  runApp(
    TsCafeApp(
      auth: auth,
      menu: ApiMenuRepository(client: client),
      // Demo orders are opt-in through `.env` and off by default — see
      // [AppConfig.useDemoOrders]. Chosen here rather than inside the
      // repository so nothing downstream can serve invented orders.
      adminMenu: ApiAdminMenuRepository(client: client),
      contact: ApiContactRepository(client: client),
      adminContact: ApiAdminContactRepository(client: client),
      adminOrders: ApiAdminOrderRepository(client: client),
      orders: AppConfig.useDemoOrders
          ? DemoOrderRepository()
          : ApiOrderRepository(client: client),
    ),
  );
}

class TsCafeApp extends StatelessWidget {
  const TsCafeApp({
    super.key,
    required this.auth,
    required this.menu,
    required this.adminMenu,
    required this.contact,
    required this.adminContact,
    required this.adminOrders,
    required this.orders,
  });

  /// Built in `main` so it can be handed the repository and wired to the
  /// client's session-expiry callback before the first frame.
  final AuthCubit auth;

  /// Provided rather than constructed per screen, so every screen that reads
  /// the menu shares one client and one set of interceptors.
  final MenuRepository menu;

  /// Managing the menu, as opposed to reading it. Provided app-wide rather than
  /// only inside the admin shell so the shell stays a plain widget — the role
  /// check in [AppRoot] is what keeps it out of a customer's reach.
  final AdminMenuRepository adminMenu;

  /// The Contact Us form. Needs no session — somebody who cannot sign in is
  /// exactly who most needs to reach the restaurant.
  final ContactRepository contact;

  /// The inbox those messages land in.
  final AdminContactRepository adminContact;

  /// The kitchen queue. Staff and admin share it — the API gives both roles the
  /// same order permissions.
  final AdminOrderRepository adminOrders;

  /// The signed-in customer's orders. Scoped to the bearer token, so it needs
  /// nothing from the session beyond the client it already shares.
  final OrderRepository orders;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<MenuRepository>.value(value: menu),
        RepositoryProvider<AdminMenuRepository>.value(value: adminMenu),
        RepositoryProvider<ContactRepository>.value(value: contact),
        RepositoryProvider<AdminContactRepository>.value(value: adminContact),
        RepositoryProvider<AdminOrderRepository>.value(value: adminOrders),
        RepositoryProvider<OrderRepository>.value(value: orders),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: auth),
          BlocProvider(create: (_) => CartCubit()),
        ],
        child: ScreenUtilInit(
          designSize: const Size(AppLayout.designWidth, AppLayout.designHeight),
          minTextAdapt: true,
          builder: (context, _) {
            return MaterialApp(
              title: "T's Café",
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: ThemeMode.system,
              home: const AppRoot(),
            );
          },
        ),
      ),
    );
  }
}

/// Decides which side of the app is on screen.
///
/// Three states, in order: the splash while startup settles, then either a
/// shell or sign-in. Because the shell is the whole subtree here, signing out
/// tears it down and signing back in mounts a fresh one — tab state never leaks
/// between sessions or roles.
class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return const SplashGate();
  }
}

/// Holds the splash for [minimumDuration], then hands over.
///
/// Two things have to finish before the app can commit to a screen: the stored
/// session has to be checked, and the splash has to have been visible long
/// enough to read. Whichever takes longer wins.
///
/// The minimum matters more than it looks. Session restore off a warm keychain
/// takes a few milliseconds, so without a floor the splash would flash for one
/// frame — worse than not having one. The maximum matters too: a slow network
/// must not hold the app on a branding screen indefinitely, so once the delay is
/// up and restore is still running, the user goes to sign-in and the shell
/// swaps in behind them if the session turns out to be good.
class SplashGate extends StatefulWidget {
  const SplashGate({super.key});

  /// Long enough to read the logo and the line under it, short enough not to
  /// feel like a loading screen.
  static const Duration minimumDuration = Duration(seconds: 2);

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  Timer? _timer;
  bool _elapsed = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(SplashGate.minimumDuration, () {
      if (mounted) setState(() => _elapsed = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      buildWhen: (a, b) => a.role != b.role || a.hasRestored != b.hasRestored,
      builder: (context, state) {
        // `hasRestored` rather than `isRestoring`: a device with no stored
        // session never issues the request, so waiting on the request itself
        // would hand over before the answer was known.
        final waiting = !_elapsed || !state.hasRestored;

        final child = switch (waiting ? null : state.role) {
          UserRole.customer => const CustomerShell(),
          // Staff share the admin shell. What they may do inside it is narrower
          // — see `UserRole.canManageVenue` — but the shape of their app is the
          // staff-facing one, not the customer's.
          UserRole.staff || UserRole.admin => const AdminShell(),
          null => waiting ? const WelcomeScreen() : const _SignedOutFlow(),
        };

        return AnimatedSwitcher(
          duration: context.motion.fade(Motion.base),
          child: KeyedSubtree(
            // Keyed on what is showing, not on the role alone: splash and
            // sign-in are both role-null, and without this the cross-fade
            // between them would not happen.
            key: ValueKey(waiting ? 'splash' : state.role),
            child: child,
          ),
        );
      },
    );
  }
}

/// Sign-in on its own navigator, so Register can be pushed and popped without
/// involving either shell.
///
/// Sign-in is the root here rather than a screen pushed over Welcome: the
/// splash is not somewhere to go back to, and leaving it on the stack put a
/// back arrow on sign-in that led nowhere useful.
class _SignedOutFlow extends StatelessWidget {
  const _SignedOutFlow();

  @override
  Widget build(BuildContext context) {
    return Navigator(
      onGenerateRoute: (settings) => AppPageRoute<void>(
        settings: settings,
        builder: (context) => const LoginScreen(),
      ),
    );
  }
}
