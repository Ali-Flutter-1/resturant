import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'core/animations/motion.dart';
import 'core/config/app_config.dart';
import 'core/network/api_client.dart';
import 'core/network/connectivity_service.dart';
import 'core/network/token_store.dart';
import 'features/auth/data/api_auth_repository.dart';
import 'features/menu/data/api_menu_repository.dart';
import 'features/menu/domain/menu_repository.dart';
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
    ),
  );
}

class TsCafeApp extends StatelessWidget {
  const TsCafeApp({super.key, required this.auth, required this.menu});

  /// Built in `main` so it can be handed the repository and wired to the
  /// client's session-expiry callback before the first frame.
  final AuthCubit auth;

  /// Provided rather than constructed per screen, so every screen that reads
  /// the menu shares one client and one set of interceptors.
  final MenuRepository menu;

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<MenuRepository>.value(
      value: menu,
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
/// Signed out, this is Welcome → Login on their own navigator. Signed in, it
/// is whichever shell the role calls for. Because the shell is the whole
/// subtree here, signing out tears it down and signing back in mounts a fresh
/// one — tab state never leaks between sessions or roles.
class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      buildWhen: (a, b) => a.role != b.role,
      builder: (context, state) {
        // Staff share the admin shell. What they may do inside it is narrower —
        // see `UserRole.canManageVenue` — but the shape of their app is the
        // staff-facing one, not the customer's.
        final child = switch (state.role) {
          UserRole.customer => const CustomerShell(),
          UserRole.staff || UserRole.admin => const AdminShell(),
          null => const _SignedOutFlow(),
        };

        return AnimatedSwitcher(
          duration: context.motion.fade(Motion.base),
          child: KeyedSubtree(key: ValueKey(state.role), child: child),
        );
      },
    );
  }
}

/// Welcome and Login sit on their own navigator so Login can be pushed and
/// popped without involving either shell.
class _SignedOutFlow extends StatelessWidget {
  const _SignedOutFlow();

  static void _pushLogin(BuildContext context) {
    Navigator.of(context).push(
      AppPageRoute<void>(
        builder: (context) =>
            LoginScreen(onBack: () => Navigator.of(context).pop()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Navigator(
      onGenerateRoute: (settings) => AppPageRoute<void>(
        settings: settings,
        builder: (context) => WelcomeScreen(
          // No sign-up screen is designed yet, so both paths land on Login.
          onGetStarted: () => _pushLogin(context),
          onLogin: () => _pushLogin(context),
        ),
      ),
    );
  }
}
