import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/animations/motion.dart';
import '../../../core/animations/reveal.dart';
import '../../../core/haptics/app_haptics.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/api_error_view.dart';
import '../../../shared/widgets/app_chip.dart';
import '../../../shared/widgets/app_sheet.dart';
import '../../../shared/widgets/app_surface.dart';
import '../../../shared/widgets/skeleton.dart';
import '../domain/admin_contact_repository.dart';
import '../domain/contact_message.dart';
import 'admin_contact_cubit.dart';
import '../../auth/session_refresh.dart';
import '../../../shared/widgets/page_body.dart';

/// The inbox behind the customers' Contact Us form.
///
/// Built because the form now reaches the server and the messages had nowhere to
/// be read — a contact form whose replies nobody sees is worse than no form,
/// since it promises an answer.
///
/// Statuses are the API's four: new, in progress, resolved, closed.
class AdminContactScreen extends StatelessWidget {
  const AdminContactScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          AdminContactCubit(repository: context.read<AdminContactRepository>())
            ..load(),
      child: const _InboxView(),
    );
  }
}

class _InboxView extends StatelessWidget {
  const _InboxView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: BlocBuilder<AdminContactCubit, AdminContactState>(
        builder: (context, state) {
          final cubit = context.read<AdminContactCubit>();

          final loading = state.status == InboxStatus.loading;

          // The search box and the status chips stay put through every state.
          // They were inside the branch, so a reload took the controls away and
          // put them back — the filter you had just tapped vanished while the
          // request it started was in flight.
          return Column(
            children: [
              _SearchField(onChanged: cubit.search).reveal(),
              const SizedBox(height: AppSpacing.x3),
              _StatusFilter(
                selected: state.filter,
                onSelected: cubit.filterBy,
              ).revealItem(1),
              const SizedBox(height: AppSpacing.x3),
              if (loading)
                // Only the list is a placeholder: everything above it is real
                // and usable.
                const Expanded(child: MessageListSkeleton())
              else if (state.status == InboxStatus.failure &&
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
                    onRefresh: () => refreshWithSession(
                      context,
                      () => cubit.load(silent: true),
                    ),
                    child: state.visible.isEmpty
                        ? _EmptyInbox(
                            filtered: state.filter != null,
                            searched: state.isSearchEmpty,
                          )
                        : ListView.separated(
                            padding: pagePadding(
                              context,
                              top: 0,
                              bottom:
                                  AppSpacing.x12 +
                                  MediaQuery.paddingOf(context).bottom,
                            ),
                            itemCount: state.visible.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: AppSpacing.x3),
                            itemBuilder: (context, index) {
                              final message = state.visible[index];
                              return _MessageRow(
                                key: ValueKey(message.id),
                                message: message,
                                busy: state.busyIds.contains(message.id),
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

/// Searches what is loaded.
class _SearchField extends StatefulWidget {
  const _SearchField({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      child: SizedBox(
        height: 44,
        child: TextField(
          controller: _controller,
          textInputAction: TextInputAction.search,
          onChanged: (value) {
            // Rebuild for the clear button, which only exists once there is
            // something to clear.
            setState(() {});
            widget.onChanged(value);
          },
          decoration: InputDecoration(
            hintText: 'Search name, subject or message...',
            prefixIcon: const Icon(Icons.search, size: AppIconSize.lg),
            suffixIcon: _controller.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close, size: AppIconSize.md),
                    tooltip: 'Clear search',
                    onPressed: () {
                      _controller.clear();
                      setState(() {});
                      widget.onChanged('');
                    },
                  ),
          ),
        ),
      ),
    );
  }
}

/// "All" plus the four states.
class _StatusFilter extends StatelessWidget {
  const _StatusFilter({required this.selected, required this.onSelected});

  final ContactStatus? selected;
  final ValueChanged<ContactStatus?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
        children: [
          SelectableChip(
            label: 'All',
            selected: selected == null,
            onSelected: () => onSelected(null),
          ),
          for (final status in ContactStatus.values) ...[
            const SizedBox(width: AppSpacing.x2),
            SelectableChip(
              label: status.label,
              selected: selected == status,
              // Tapping the selected one clears it, same as tapping "All".
              onSelected: () => onSelected(selected == status ? null : status),
            ),
          ],
        ],
      ),
    );
  }
}

/// One message, summarised.
class _MessageRow extends StatelessWidget {
  const _MessageRow({super.key, required this.message, required this.busy});

  final ContactMessage message;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final unread = message.status == ContactStatus.newMessage;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: busy
            ? null
            : () {
                AppHaptics.toggle();
                _showMessage(context, message);
              },
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: AppSurface.row(
          padding: const EdgeInsets.all(AppSpacing.x4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // A dot, not bold text: it survives being scanned down a long
              // list, and it does not change the row's height.
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.x1 + 2),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: unread
                        ? Theme.of(context).colorScheme.primary
                        : Colors.transparent,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            message.name,
                            style: context.texts.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.x2),
                        _StatusChip(status: message.status),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message.heading,
                      style: context.texts.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.x1),
                    Text(
                      message.message,
                      style: context.texts.bodySmall?.copyWith(
                        color: context.surfaces.inkSoft,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (message.createdAt != null) ...[
                      const SizedBox(height: AppSpacing.x2),
                      Text(
                        _when(message.createdAt!),
                        style: context.texts.bodySmall?.copyWith(
                          color: context.surfaces.inkSoft,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final ContactStatus status;

  @override
  Widget build(BuildContext context) {
    final colours = context.orderColors;
    final (foreground, background) = switch (status) {
      ContactStatus.newMessage => (
        colours.preparing,
        colours.preparingContainer,
      ),
      ContactStatus.inProgress => (colours.ready, colours.readyContainer),
      ContactStatus.resolved => (colours.served, colours.servedContainer),
      ContactStatus.closed => (colours.served, colours.servedContainer),
    };

    return AppChip.status(
      label: status.label,
      foreground: foreground,
      background: background,
    );
  }
}

/// The message in full, with the two things an admin can change.
void _showMessage(BuildContext context, ContactMessage message) {
  final cubit = context.read<AdminContactCubit>();
  showAppSheet<void>(
    context: context,
    title: message.name,
    subtitle: message.heading,
    child: BlocProvider.value(
      value: cubit,
      child: _MessageDetail(id: message.id),
    ),
  );
}

class _MessageDetail extends StatefulWidget {
  const _MessageDetail({required this.id});

  final String id;

  @override
  State<_MessageDetail> createState() => _MessageDetailState();
}

class _MessageDetailState extends State<_MessageDetail> {
  final _note = TextEditingController();

  /// The message as it was when the sheet opened, to compare against.
  ContactMessage? _original;

  /// The status the admin has *chosen*, which is not necessarily the one the
  /// server has. Staged rather than sent on tap: the sheet has a save button, so
  /// nothing in it should save itself — tapping "Resolved" to see what it says
  /// used to commit it.
  ContactStatus? _status;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  /// Seeds the form once, from the message the list already carries.
  void _seed(ContactMessage message) {
    if (_original != null) return;
    _original = message;
    _status = message.status;
    _note.text = message.adminNote ?? '';
  }

  bool get _statusChanged =>
      _original != null && _status != null && _status != _original!.status;

  bool get _noteChanged =>
      _original != null && _note.text.trim() != (_original!.adminNote ?? '');

  bool get _dirty => _statusChanged || _noteChanged;

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final original = _original;
    if (original == null || !_dirty) return;

    // Only what actually changed. Sending both every time would rewrite a note
    // when the admin only touched the status, and vice versa.
    final error = await context.read<AdminContactCubit>().update(
      widget.id,
      status: _statusChanged ? _status : null,
      adminNote: _noteChanged ? _note.text.trim() : null,
    );
    if (!mounted) return;

    if (error != null) {
      AppHaptics.failure();
      // Nothing is reset: a refused save must not cost the admin what they
      // chose or typed.
      showAppSnack(context, error, isError: true);
      return;
    }

    AppHaptics.success();
    Navigator.of(context).pop();
    showAppSnack(context, 'Message updated.');
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AdminContactCubit, AdminContactState>(
      builder: (context, state) {
        final message = state.messages.firstWhere(
          (m) => m.id == widget.id,
          // Removed under us — the sheet closes rather than throwing.
          orElse: () => const ContactMessage(
            id: '',
            name: '',
            email: '',
            message: '',
            status: ContactStatus.newMessage,
          ),
        );
        if (message.id.isEmpty) return const SizedBox.shrink();

        // Seeded once, so a rebuild does not overwrite what is being typed or
        // the status just chosen.
        _seed(message);
        final busy = state.busyIds.contains(message.id);

        // Scrollable. The sheet gives its child a bounded height, so with the
        // keyboard up the content was squeezed and the save button went off the
        // bottom with no way to reach it. The keyboard's own inset is added to
        // the padding so the last field can always be scrolled clear of it.
        return SingleChildScrollView(
          padding: pagePadding(
            context,
            top: 0,
            bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.x4,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tappable, because the point of a message is to answer it.
              _ContactLine(
                icon: Icons.mail_outline,
                value: message.email,
                onTap: () => _copy(context, message.email),
              ),
              if (message.phone != null)
                _ContactLine(
                  icon: Icons.phone_outlined,
                  value: message.phone!,
                  onTap: () => _copy(context, message.phone!),
                ),
              const SizedBox(height: AppSpacing.x4),

              // The sender's own words, never editable: this is a record of
              // what somebody said, not a document to tidy up.
              SelectableText(message.message, style: context.texts.bodyLarge),
              const SizedBox(height: AppSpacing.x5),

              Text('Status', style: context.texts.titleMedium),
              const SizedBox(height: AppSpacing.x2),
              Wrap(
                spacing: AppSpacing.x2,
                runSpacing: AppSpacing.x2,
                children: [
                  for (final status in ContactStatus.values)
                    SelectableChip(
                      label: status.label,
                      // The staged choice, not the server's — so the selection
                      // follows the tap and the save button becomes live.
                      selected: _status == status,
                      onSelected: busy
                          ? null
                          : () => setState(() => _status = status),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.x5),

              Row(
                children: [
                  Text('Private note', style: context.texts.titleMedium),
                  const SizedBox(width: AppSpacing.x2),
                  // Flexible: the pair is wider than a 320pt sheet, and a
                  // header that overflows hides the half that explains what
                  // "private" means.
                  Flexible(
                    child: Text(
                      'The sender never sees this',
                      style: context.texts.bodySmall?.copyWith(
                        color: context.surfaces.inkSoft,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.x2),
              TextField(
                controller: _note,
                enabled: !busy,
                maxLines: 3,
                maxLength: 2000,
                // Rebuild so the save button tracks whether anything changed.
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Who is handling this, and what was agreed?',
                ),
              ),
              const SizedBox(height: AppSpacing.x2),

              // Disabled until something has actually changed, so the button
              // states plainly whether there is anything to save. It is also the
              // only thing that writes: the status chips above stage a choice.
              FilledButton(
                onPressed: busy || !_dirty ? null : _save,
                child: Text(busy ? 'Saving…' : 'Save changes'),
              ),
              if (_dirty && !busy) ...[
                const SizedBox(height: AppSpacing.x2),
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: AppIconSize.sm,
                      color: context.surfaces.inkSoft,
                    ),
                    const SizedBox(width: AppSpacing.x2),
                    Flexible(
                      child: Text(
                        'Not saved yet.',
                        style: context.texts.bodySmall?.copyWith(
                          color: context.surfaces.inkSoft,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _copy(BuildContext context, String value) {
    AppHaptics.selection();
    showAppSnack(context, value, icon: Icons.content_copy);
  }
}

class _ContactLine extends StatelessWidget {
  const _ContactLine({required this.icon, required this.value, this.onTap});

  final IconData icon;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.x2),
        child: Row(
          children: [
            Icon(icon, size: AppIconSize.lg, color: context.surfaces.inkSoft),
            const SizedBox(width: AppSpacing.x3),
            Expanded(
              child: SelectableText(value, style: context.texts.bodyMedium),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyInbox extends StatelessWidget {
  const _EmptyInbox({required this.filtered, this.searched = false});

  final bool filtered;

  /// True when a search hid everything, which is not the same as an empty inbox.
  final bool searched;

  @override
  Widget build(BuildContext context) {
    return ListView(
      // Scrollable so pull-to-refresh works on an empty inbox, which is exactly
      // when somebody will try it.
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.18),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.x8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  filtered
                      ? Icons.filter_alt_off_outlined
                      : Icons.mark_email_read_outlined,
                  size: AppIconSize.hero,
                  color: context.surfaces.inkSoft,
                ),
                const SizedBox(height: AppSpacing.x4),
                Text(
                  searched
                      ? 'No matches'
                      : filtered
                      ? 'Nothing in this state'
                      : 'No messages',
                  style: context.texts.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.x2),
                Text(
                  searched
                      ? 'Nothing loaded matches that. Try fewer words.'
                      : filtered
                      ? 'Try another status, or show all.'
                      : 'Messages from the Contact Us form arrive here.',
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

/// A date a person can read at a glance.
String _when(DateTime when) {
  final now = DateTime.now();
  final day = DateTime(when.year, when.month, when.day);
  final today = DateTime(now.year, now.month, now.day);
  final difference = today.difference(day).inDays;
  final time =
      '${when.hour.toString().padLeft(2, '0')}:'
      '${when.minute.toString().padLeft(2, '0')}';

  if (difference == 0) return 'Today, $time';
  if (difference == 1) return 'Yesterday, $time';
  return '${when.day} ${_months[when.month - 1]}'
      '${when.year == now.year ? '' : ' ${when.year}'}';
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
