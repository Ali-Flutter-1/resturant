import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'core/animations/motion.dart';
import 'core/animations/page_transitions.dart';
import 'core/theme/app_spacing.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_cubit.dart';
import 'features/auth/login_screen.dart';
import 'features/cart/cart_cubit.dart';
import 'features/shell/admin_shell.dart';
import 'features/shell/customer_shell.dart';
import 'features/welcome/presentation/welcome_screen.dart';

void main() {
  runApp(const TsCafeApp());
}

class TsCafeApp extends StatelessWidget {
  const TsCafeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => AuthCubit()),
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
        final child = switch (state.role) {
          UserRole.customer => const CustomerShell(),
          UserRole.admin => const AdminShell(),
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
