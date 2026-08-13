import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/animations/motion.dart';
import '../../../core/animations/reveal.dart';
import '../../../core/haptics/app_haptics.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/api_error_view.dart';
import '../../../shared/widgets/app_chip.dart';
import '../../../shared/widgets/app_sheet.dart';
import '../../../shared/widgets/app_surface.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../auth/auth_cubit.dart';
import '../domain/admin_user.dart';
import '../domain/admin_user_repository.dart';
import 'admin_users_cubit.dart';

/// Accounts, for an administrator.
///
/// Deliberately narrow, because the API is: a role, an active flag, and closing
/// an account. There is no route to edit somebody else's name, email or password,
/// and offering fields for them would promise something the backend refuses.
///
/// Every guard is also enforced server-side — the last active admin cannot be
/// demoted, nobody can edit themselves — so the buttons here are disabled for
/// clarity and the server's answer is still the one that decides.
class AdminUsersScreen extends StatelessWidget {
  const AdminUsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          AdminUsersCubit(repository: context.read<AdminUserRepository>())
            ..load(),
      child: const _UsersView(),
    );
  }
}

class _UsersView extends StatefulWidget {
  const _UsersView();

  @override
  State<_UsersView> createState() => _UsersViewState();
}

class _UsersViewState extends State<_UsersView> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The signed-in admin, so their own row can be marked and its actions
    // disabled. The backend refuses self-edits anyway; this saves the trip.
    final me = context.select((AuthCubit c) => c.state.user?.id);

    return Scaffold(
      appBar: AppBar(title: const Text('Users')),
      body: BlocBuilder<AdminUsersCubit, AdminUsersState>(
        builder: (context, state) {
          final cubit = context.read<AdminUsersCubit>();
          final loading = state.status == UsersStatus.loading;

          return Column(
            children: [
              _StatsStrip(stats: state.stats, loading: loading).reveal(),
              const SizedBox(height: AppSpacing.x3),
              _SearchField(
                controller: _search,
                onChanged: cubit.search,
              ).revealItem(1),
              const SizedBox(height: AppSpacing.x3),
              _Filters(state: state, cubit: cubit).revealItem(2),
              const SizedBox(height: AppSpacing.x3),
              if (loading)
                const Expanded(child: MessageListSkeleton())
              else if (state.status == UsersStatus.failure &&
                  state.failure != null)
                Expanded(
                  child: ApiErrorView(
                    failure: state.failure!,
                    onRetry: () => cubit.load(),
                  ),
                )
              else
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () => cubit.load(silent: true),
                    child: state.users.isEmpty
                        ? _NoUsers(filtered: state.hasFilters)
                        : ListView.separated(
                            padding: EdgeInsets.fromLTRB(
                              AppSpacing.gutter,
                              0,
                              AppSpacing.gutter,
                              AppSpacing.x12 +
                                  MediaQuery.paddingOf(context).bottom,
                            ),
                            // One extra row for the pager at the end.
                            itemCount: state.users.length + 1,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: AppSpacing.x3),
                            itemBuilder: (context, index) {
                              if (index == state.users.length) {
                                return _Pager(state: state, cubit: cubit);
                              }
                              final user = state.users[index];
                              return _UserRow(
                                key: ValueKey(user.id),
                                user: user,
                                isSelf: user.id == me,
                                busy: state.busyIds.contains(user.id),
                                onOpen: () =>
                                    _showUser(context, user, isSelf: user.id == me),
                              ).revealItem(index, duration: Motion.fast);
                            },
                          ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _StatsStrip extends StatelessWidget {
  const _StatsStrip({required this.stats, required this.loading});

  final UserStats stats;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    String value(int n) => loading ? '—' : '$n';

    return SizedBox(
      height: 74,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
        children: [
          _Tile(label: 'Active', value: value(stats.active), emphasise: true),
          const SizedBox(width: AppSpacing.x3),
          _Tile(label: 'Customers', value: value(stats.customers)),
          const SizedBox(width: AppSpacing.x3),
          _Tile(label: 'Staff', value: value(stats.staff)),
          const SizedBox(width: AppSpacing.x3),
          _Tile(label: 'Admins', value: value(stats.admins)),
          const SizedBox(width: AppSpacing.x3),
          _Tile(label: 'Closed', value: value(stats.deleted)),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.label,
    required this.value,
    this.emphasise = false,
  });

  final String label;
  final String value;
  final bool emphasise;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: 96,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x3,
        vertical: AppSpacing.x2,
      ),
      decoration: BoxDecoration(
        color: emphasise ? scheme.primary : context.surfaces.ground,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: emphasise ? null : Border.all(color: context.surfaces.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label.toUpperCase(),
            style: AppTypography.caption(
              emphasise ? scheme.onPrimary : context.surfaces.inkSoft,
            ),
          ),
          const SizedBox(height: 2),
          Flexible(
            child: FittedBox(
              child: Text(
                value,
                style: context.texts.headlineMedium?.copyWith(
                  color: emphasise ? scheme.onPrimary : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      child: SizedBox(
        height: 44,
        child: TextField(
          controller: controller,
          textInputAction: TextInputAction.search,
          onChanged: onChanged,
          decoration: const InputDecoration(
            hintText: 'Search a name or email...',
            prefixIcon: Icon(Icons.search, size: AppIconSize.lg),
          ),
        ),
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({required this.state, required this.cubit});

  final AdminUsersState state;
  final AdminUsersCubit cubit;

  @override
  Widget build(BuildContext context) {
    // One choice, not five toggles. Role and account state are separate query
    // parameters, but on screen they are a single strip, and letting two chips
    // light up at once made it read as multi-select — with no way to tell which
    // combination was actually in force.
    final options = <({String label, UserRole? role, bool? isActive})>[
      (label: 'Everyone', role: null, isActive: null),
      (label: 'Customers', role: UserRole.customer, isActive: null),
      (label: 'Staff', role: UserRole.staff, isActive: null),
      (label: 'Admins', role: UserRole.admin, isActive: null),
      (label: 'Deactivated', role: null, isActive: false),
    ];

    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
        children: [
          for (final (index, option) in options.indexed) ...[
            if (index > 0) const SizedBox(width: AppSpacing.x2),
            SelectableChip(
              label: option.label,
              selected:
                  state.role == option.role && state.isActive == option.isActive,
              onSelected: () => cubit.setFilter(
                role: option.role,
                isActive: option.isActive,
              ),
            ),
          ],
          // Set apart, because this one genuinely is an independent toggle: it
          // widens whichever filter is chosen rather than replacing it. Closed
          // accounts are hidden by default — they are history rather than people
          // to manage.
          const SizedBox(width: AppSpacing.x4),
          _StripDivider(),
          const SizedBox(width: AppSpacing.x4),
          SelectableChip(
            label: 'Include closed',
            selected: state.includeDeleted,
            onSelected: () => cubit.showClosed(!state.includeDeleted),
          ),
        ],
      ),
    );
  }
}

/// Separates the mutually-exclusive filters from the independent toggle.
class _StripDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 1,
        height: 20,
        child: ColoredBox(color: context.surfaces.line),
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({
    super.key,
    required this.user,
    required this.isSelf,
    required this.busy,
    required this.onOpen,
  });

  final AdminUser user;
  final bool isSelf;
  final bool busy;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final closed = user.state == AccountState.closed;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: busy ? null : onOpen,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Opacity(
          // A closed account recedes: it is a record, not somebody to act on.
          opacity: closed ? 0.6 : 1,
          child: AppSurface.row(
            padding: const EdgeInsets.all(AppSpacing.x4),
            child: Row(
              children: [
                _Avatar(user: user),
                const SizedBox(width: AppSpacing.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              user.displayName,
                              style: context.texts.titleMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isSelf) ...[
                            const SizedBox(width: AppSpacing.x2),
                            // Marked, because an admin about to change a role
                            // needs to know which row is theirs.
                            AppChip.outlined(label: 'You'),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user.email,
                        style: context.texts.bodySmall?.copyWith(
                          color: context.surfaces.inkSoft,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.x2),
                      // Wrapped, not a Row: "CUSTOMER" beside "DEACTIVATED"
                      // runs past a narrow row, and the badges matter more than
                      // keeping them on one line.
                      Wrap(
                        spacing: AppSpacing.x2,
                        runSpacing: AppSpacing.x2,
                        children: [
                          _RoleChip(user: user),
                          _StateChip(state: user.state),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.user});

  final AdminUser user;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final avatar = user.avatarUrl;

    return Container(
      width: 44,
      height: 44,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.surfaces.accentContainer,
      ),
      child: avatar == null || avatar.isEmpty
          ? Center(
              child: Icon(
                switch (user.role) {
                  UserRole.customer => Icons.person,
                  UserRole.staff => Icons.room_service,
                  UserRole.admin => Icons.admin_panel_settings,
                },
                size: AppIconSize.xl,
                color: scheme.primary,
              ),
            )
          : Image.network(
              avatar,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (context, _, _) => Center(
                child: Icon(Icons.person, color: scheme.primary),
              ),
            ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.user});

  final AdminUser user;

  @override
  Widget build(BuildContext context) {
    final colours = context.orderColors;
    final (foreground, background) = switch (user.role) {
      UserRole.customer => (colours.served, colours.servedContainer),
      UserRole.staff => (colours.preparing, colours.preparingContainer),
      UserRole.admin => (colours.ready, colours.readyContainer),
    };

    return AppChip.status(
      label: user.roleLabel,
      foreground: foreground,
      background: background,
    );
  }
}

class _StateChip extends StatelessWidget {
  const _StateChip({required this.state});

  final AccountState state;

  @override
  Widget build(BuildContext context) {
    if (state == AccountState.active) return const SizedBox.shrink();
    final colours = context.orderColors;

    return AppChip.status(
      label: state.label,
      foreground: colours.overdue,
      background: colours.overdueContainer,
    );
  }
}

class _Pager extends StatelessWidget {
  const _Pager({required this.state, required this.cubit});

  final AdminUsersState state;
  final AdminUsersCubit cubit;

  @override
  Widget build(BuildContext context) {
    if (!state.hasMore) {
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.x2),
        child: Center(
          child: Text(
            '${state.users.length} of ${state.total} shown',
            style: context.texts.bodySmall?.copyWith(
              color: context.surfaces.inkSoft,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.x2),
      child: Center(
        child: state.loadingMore
            ? const Padding(
                padding: EdgeInsets.all(AppSpacing.x3),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : OutlinedButton(
                onPressed: cubit.loadMore,
                child: Text(
                  'Load more · ${state.users.length} of ${state.total}',
                ),
              ),
      ),
    );
  }
}

/// One account, and everything an admin may do to it.
void _showUser(BuildContext context, AdminUser user, {required bool isSelf}) {
  final cubit = context.read<AdminUsersCubit>();
  showAppSheet<void>(
    context: context,
    title: user.displayName,
    subtitle: user.email,
    child: BlocProvider.value(
      value: cubit,
      child: _UserDetail(id: user.id, isSelf: isSelf),
    ),
  );
}

class _UserDetail extends StatelessWidget {
  const _UserDetail({required this.id, required this.isSelf});

  final String id;
  final bool isSelf;

  Future<void> _setRole(BuildContext context, AdminUser user, UserRole role) async {
    // Granting or removing administrator access is confirmed. The rest are a
    // tap: promoting somebody to staff is routine and reversible.
    final touchesAdmin = role == UserRole.admin || user.role == UserRole.admin;
    if (touchesAdmin) {
      final confirmed = await _confirm(
        context,
        title: role == UserRole.admin
            ? 'Make ${user.displayName} an administrator?'
            : 'Remove admin access from ${user.displayName}?',
        body: role == UserRole.admin
            ? 'They will be able to manage the menu, the floor, every order and '
                  'every account — including yours.'
            : 'They will lose access to accounts, the menu and the floor.',
        action: role == UserRole.admin ? 'Make admin' : 'Remove access',
      );
      if (confirmed != true || !context.mounted) return;
    }

    final error = await context.read<AdminUsersCubit>().update(
      user.id,
      role: role,
    );
    if (!context.mounted) return;
    _report(context, error, 'Role updated.');
  }

  Future<void> _setActive(
    BuildContext context,
    AdminUser user,
    bool active,
  ) async {
    if (!active) {
      final confirmed = await _confirm(
        context,
        title: 'Deactivate ${user.displayName}?',
        body: 'They are signed out everywhere and cannot sign in again until '
            'you reactivate them. Their orders and bookings are untouched.',
        action: 'Deactivate',
      );
      if (confirmed != true || !context.mounted) return;
    }

    final error = await context.read<AdminUsersCubit>().update(
      user.id,
      isActive: active,
    );
    if (!context.mounted) return;
    _report(context, error, active ? 'Reactivated.' : 'Deactivated.');
  }

  Future<void> _close(BuildContext context, AdminUser user) async {
    final confirmed = await _confirm(
      context,
      title: 'Close this account permanently?',
      body: 'Personal details are removed, every session is signed out, and '
          'this cannot be reversed here. Past orders and bookings stay, '
          'anonymised, for the accounts.',
      action: 'Close account',
    );
    if (confirmed != true || !context.mounted) return;

    final error = await context.read<AdminUsersCubit>().closeAccount(user.id);
    if (!context.mounted) return;
    if (error == null) Navigator.of(context).pop();
    _report(context, error, 'Account closed.');
  }

  static void _report(BuildContext context, String? error, String success) {
    if (error != null) {
      AppHaptics.failure();
      // The API's own words — LAST_ACTIVE_ADMIN and CANNOT_EDIT_SELF both say
      // exactly what happened, and nothing local is changed.
      showAppSnack(context, error, isError: true);
      return;
    }
    AppHaptics.success();
    showAppSnack(context, success);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AdminUsersCubit, AdminUsersState>(
      builder: (context, state) {
        final user = state.users.where((u) => u.id == id).firstOrNull;
        if (user == null) return const SizedBox.shrink();

        final busy = state.busyIds.contains(user.id);
        // Self-actions are disabled here as well as refused by the API: a button
        // that always fails is worse than one that is plainly unavailable.
        final canAct = user.isEditable && !isSelf && !busy;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            0,
            AppSpacing.gutter,
            MediaQuery.viewInsetsOf(context).bottom + AppSpacing.x4,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: AppSpacing.x2,
                runSpacing: AppSpacing.x2,
                children: [
                  _RoleChip(user: user),
                  _StateChip(state: user.state),
                ],
              ),
              const SizedBox(height: AppSpacing.x4),

              // How they sign in — not the credentials themselves, which the API
              // never sends.
              _Detail(
                label: 'Signs in with',
                value: [
                  if (user.hasPassword) 'Password',
                  if (user.hasGoogle) 'Google',
                ].join(' and ').ifEmpty('No sign-in method'),
              ),
              _Detail(
                label: 'Email',
                value: user.isEmailVerified ? 'Verified' : 'Not verified',
              ),
              if (user.lastLoginAt != null)
                _Detail(label: 'Last signed in', value: _date(user.lastLoginAt!)),
              if (user.createdAt != null)
                _Detail(label: 'Joined', value: _date(user.createdAt!)),

              const SizedBox(height: AppSpacing.x5),

              if (isSelf)
                _Note(
                  'This is your own account. Roles and access are changed by '
                  'another administrator.',
                )
              else if (!user.isEditable)
                _Note('This account is closed and cannot be changed.')
              else ...[
                Text('Role', style: context.texts.titleMedium),
                const SizedBox(height: AppSpacing.x2),
                Wrap(
                  spacing: AppSpacing.x2,
                  runSpacing: AppSpacing.x2,
                  children: [
                    for (final role in UserRole.values)
                      SelectableChip(
                        label: switch (role) {
                          UserRole.customer => 'Customer',
                          UserRole.staff => 'Staff',
                          UserRole.admin => 'Admin',
                        },
                        selected: user.role == role,
                        onSelected: !canAct || user.role == role
                            ? null
                            : () => _setRole(context, user, role),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.x5),

                if (user.isActive)
                  OutlinedButton.icon(
                    onPressed: canAct
                        ? () => _setActive(context, user, false)
                        : null,
                    icon: const Icon(Icons.block, size: AppIconSize.md),
                    label: const Text('Deactivate'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                    ),
                  )
                else
                  FilledButton.icon(
                    onPressed: canAct
                        ? () => _setActive(context, user, true)
                        : null,
                    icon: const Icon(Icons.check, size: AppIconSize.md),
                    label: const Text('Reactivate'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                    ),
                  ),
                const SizedBox(height: AppSpacing.x2),
                TextButton.icon(
                  onPressed: canAct ? () => _close(context, user) : null,
                  icon: const Icon(Icons.person_off, size: AppIconSize.md),
                  label: const Text('Close account'),
                  style: TextButton.styleFrom(
                    foregroundColor: context.orderColors.overdue,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 116,
            child: Text(
              label,
              style: context.texts.bodySmall?.copyWith(
                color: context.surfaces.inkSoft,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.x3),
          Expanded(child: Text(value, style: context.texts.bodyMedium)),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x3),
      decoration: BoxDecoration(
        color: context.surfaces.ground,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: context.surfaces.line),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: AppIconSize.md,
            color: context.surfaces.inkSoft,
          ),
          const SizedBox(width: AppSpacing.x2),
          Expanded(
            child: Text(
              text,
              style: context.texts.bodySmall?.copyWith(
                color: context.surfaces.inkSoft,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A destructive confirmation.
Future<bool?> _confirm(
  BuildContext context, {
  required String title,
  required String body,
  required String action,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Leave it'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(
            foregroundColor: context.orderColors.overdue,
          ),
          child: Text(action),
        ),
      ],
    ),
  );
}

class _NoUsers extends StatelessWidget {
  const _NoUsers({required this.filtered});

  final bool filtered;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.14),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.x8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  filtered ? Icons.search_off : Icons.people_outline,
                  size: AppIconSize.hero,
                  color: context.surfaces.inkSoft,
                ),
                const SizedBox(height: AppSpacing.x4),
                Text(
                  filtered ? 'No matches' : 'No accounts yet',
                  style: context.texts.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.x2),
                Text(
                  filtered
                      ? 'Try a different search or clear the filters.'
                      : 'Accounts appear here as people register.',
                  style: context.texts.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}

String _date(DateTime when) {
  final now = DateTime.now();
  final day = DateTime(when.year, when.month, when.day);
  final today = DateTime(now.year, now.month, now.day);
  final difference = today.difference(day).inDays;
  final time =
      '${when.hour.toString().padLeft(2, '0')}:'
      '${when.minute.toString().padLeft(2, '0')}';

  if (difference == 0) return 'Today, $time';
  if (difference == 1) return 'Yesterday, $time';
  return '${when.day}/${when.month}/${when.year}';
}
