import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/animations/reveal.dart';
import '../../../core/haptics/app_haptics.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/api_error_view.dart';
import '../../../shared/widgets/app_chip.dart';
import '../../../shared/widgets/app_sheet.dart';
import '../../../shared/widgets/app_surface.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../auth/session_refresh.dart';
import '../domain/reservation_repository.dart';
import '../domain/venue_table.dart';
import 'venue_cubit.dart';
import '../../../shared/widgets/page_body.dart';

/// The room and the timetable. Admin only.
///
/// Two tabs, because they are two jobs: the tables are the room, and the
/// sittings are when it is sold. Both are configuration rather than daily work,
/// which is why this lives behind the admin profile rather than being a tab of
/// its own.
class AdminVenueScreen extends StatelessWidget {
  const AdminVenueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          VenueCubit(repository: context.read<VenueRepository>())..load(),
      child: const _VenueView(),
    );
  }
}

class _VenueView extends StatelessWidget {
  const _VenueView();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tables & sittings'),
          actions: [
            Builder(
              builder: (context) => IconButton(
                onPressed: () => _editTable(context, null),
                icon: const Icon(Icons.add),
                tooltip: 'New table',
              ),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Tables'),
              Tab(text: 'Sittings'),
            ],
          ),
        ),
        body: BlocBuilder<VenueCubit, VenueState>(
          builder: (context, state) {
            final cubit = context.read<VenueCubit>();

            if (state.status == VenueStatus.loading) {
              return const MessageListSkeleton();
            }
            if (state.status == VenueStatus.failure && state.failure != null) {
              return ApiErrorView(
                failure: state.failure!,
                onRetry: () => cubit.load(),
              );
            }

            return TabBarView(
              children: [
                _TablesTab(state: state),
                _SittingsTab(state: state),
              ],
            );
          },
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------- tables

class _TablesTab extends StatelessWidget {
  const _TablesTab({required this.state});

  final VenueState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<VenueCubit>();

    return RefreshIndicator(
      onRefresh: () =>
          refreshWithSession(context, () => cubit.load(silent: true)),
      child: ListView(
        padding: pagePadding(
          context,
          top: AppSpacing.x4,
          bottom: AppSpacing.x12 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          // On its own row. "New table" is an app-bar action, where a
          // primary create belongs, rather than competing with a filter.
          Align(
            alignment: Alignment.centerLeft,
            child: SelectableChip(
              label: 'Show archived',
              selected: state.includeArchived,
              onSelected: () => cubit.showArchived(!state.includeArchived),
            ),
          ),
          const SizedBox(height: AppSpacing.x4),
          // The state an admin lands in after adding their first table and
          // wondering why nobody can book: the room exists, the timetable
          // does not. Said here rather than left to be discovered.
          if (state.liveTables.isNotEmpty && state.slots.isEmpty) ...[
            _NothingBookable(),
            const SizedBox(height: AppSpacing.x4),
          ],
          if (state.tables.isEmpty)
            _Empty(
              icon: Icons.table_restaurant_outlined,
              title: 'No tables yet',
              body:
                  'Add the room first. Sittings are generated per table, so '
                  'nothing can be booked until at least one exists.',
            )
          else
            for (final table in state.tables) ...[
              _TableCard(table: table, busy: state.busyIds.contains(table.id)),
              const SizedBox(height: AppSpacing.x3),
            ],
        ].revealStaggered(),
      ),
    );
  }
}

/// Tables with no sittings cannot be booked, and nothing else says so.
class _NothingBookable extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colours = context.orderColors;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.x3),
      decoration: BoxDecoration(
        color: colours.preparingContainer,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: AppIconSize.md,
                color: colours.preparing,
              ),
              const SizedBox(width: AppSpacing.x2),
              Expanded(
                child: Text(
                  'Nothing can be booked yet',
                  style: context.texts.titleSmall?.copyWith(
                    color: colours.preparing,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Customers pick a sitting, not a table. Generate some and the room '
            'becomes bookable.',
            style: context.texts.bodySmall,
          ),
          const SizedBox(height: AppSpacing.x2),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: () => _openGenerator(context),
              child: const Text('Generate sittings'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Switches to the Sittings tab and opens the generator.
///
/// Reached from the Tables tab too, because that is where an admin is standing
/// when they discover the room is not bookable.
void _openGenerator(BuildContext context) {
  final controller = DefaultTabController.of(context);
  controller.animateTo(1);
  final cubit = context.read<VenueCubit>();
  // After the tab settles, so the sheet does not open over a moving page.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (context.mounted) _generate(context, cubit.state);
  });
}

class _TableCard extends StatelessWidget {
  const _TableCard({required this.table, required this.busy});

  final VenueTable table;
  final bool busy;

  Future<void> _archive(BuildContext context) async {
    // Read before the dialog: after two awaits this element may be gone, and
    // `context.read` on a defunct element throws rather than returning null.
    final cubit = context.read<VenueCubit>();
    final confirmed = await _confirm(
      context,
      title: 'Archive ${table.name}?',
      body:
          'It disappears from availability. Existing bookings are untouched, '
          'and the API refuses this while upcoming ones exist.',
      action: 'Archive',
    );
    if (confirmed != true || !context.mounted) return;

    final error = await cubit.archiveTable(table.id);
    if (!context.mounted) return;
    _report(context, error);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<VenueCubit>();

    return Opacity(
      opacity: table.isArchived ? 0.6 : 1,
      child: AppSurface.row(
        padding: const EdgeInsets.all(AppSpacing.x4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(table.name, style: context.texts.titleMedium),
                ),
                AppChip.outlined(label: table.seatsLabel),
                const SizedBox(width: AppSpacing.x2),
                _StateChip(table: table),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              [
                table.area.label,
                if (!table.isFree) table.priceLabel,
                if (table.description != null) table.description!,
              ].join(' · '),
              style: context.texts.bodySmall?.copyWith(
                color: context.surfaces.inkSoft,
              ),
            ),
            const SizedBox(height: AppSpacing.x2),
            Wrap(
              spacing: AppSpacing.x2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (table.isArchived)
                  TextButton(
                    onPressed: busy
                        ? null
                        : () async {
                            final error = await cubit.restoreTable(table.id);
                            if (!context.mounted) return;
                            _report(
                              context,
                              error,
                              // Said out loud, because the API restores without
                              // making the table live and an admin who assumes
                              // otherwise will wonder why nobody can book it.
                              success:
                                  '${table.name} restored. Switch it on to '
                                  'make it bookable.',
                            );
                          },
                    child: const Text('Restore'),
                  )
                else ...[
                  TextButton(
                    onPressed: busy ? null : () => _editTable(context, table),
                    child: const Text('Edit'),
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () async {
                            final error = await cubit.setTableActive(
                              table.id,
                              !table.isActive,
                            );
                            if (!context.mounted) return;
                            _report(context, error);
                          },
                    child: Text(table.isActive ? 'Hide' : 'Show'),
                  ),
                  TextButton(
                    onPressed: busy ? null : () => _archive(context),
                    style: TextButton.styleFrom(
                      foregroundColor: context.orderColors.overdue,
                    ),
                    child: const Text('Archive'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StateChip extends StatelessWidget {
  const _StateChip({required this.table});

  final VenueTable table;

  @override
  Widget build(BuildContext context) {
    final colours = context.orderColors;
    final (foreground, background) = table.isArchived
        ? (colours.overdue, colours.overdueContainer)
        : table.isActive
        ? (colours.ready, colours.readyContainer)
        : (colours.preparing, colours.preparingContainer);

    return AppChip.status(
      label: table.stateLabel,
      foreground: foreground,
      background: background,
    );
  }
}

/// Create or edit a table.
Future<void> _editTable(BuildContext context, VenueTable? existing) async {
  final cubit = context.read<VenueCubit>();
  await showAppSheet<void>(
    context: context,
    title: existing == null ? 'New table' : existing.name,
    child: BlocProvider.value(
      value: cubit,
      child: _TableForm(existing: existing),
    ),
  );
}

class _TableForm extends StatefulWidget {
  const _TableForm({this.existing});

  final VenueTable? existing;

  @override
  State<_TableForm> createState() => _TableFormState();
}

class _TableFormState extends State<_TableForm> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _description = TextEditingController(
    text: widget.existing?.description ?? '',
  );
  late final _price = TextEditingController(
    text: '${widget.existing?.bookingPricePence ?? 0}',
  );
  late int _seats = widget.existing?.seats ?? 4;
  late TableArea _area = widget.existing?.area ?? TableArea.indoor;
  late bool _isActive = widget.existing?.isActive ?? true;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      showAppSnack(context, 'A table needs a name.', isError: true);
      return;
    }

    setState(() => _saving = true);
    final error = await context.read<VenueCubit>().saveTable(
      VenueTable(
        id: widget.existing?.id ?? '',
        name: name,
        seats: _seats,
        area: _area,
        description: _description.text.trim().isEmpty
            ? null
            : _description.text.trim(),
        // Integer pence, read as an integer. A price field parsed as a double is
        // how totals end up a penny out.
        bookingPricePence: int.tryParse(_price.text.trim()) ?? 0,
        sortOrder: widget.existing?.sortOrder ?? 0,
        isActive: _isActive,
        isArchived: widget.existing?.isArchived ?? false,
      ),
    );
    if (!mounted) return;
    setState(() => _saving = false);

    if (error != null) {
      AppHaptics.failure();
      showAppSnack(context, error, isError: true);
      return;
    }
    AppHaptics.success();
    Navigator.of(context).pop();
    showAppSnack(context, 'Table saved.');
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: pagePadding(
        context,
        top: 0,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.x4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Field(label: 'Name', controller: _name, hint: 'Window Table 1'),
          const SizedBox(height: AppSpacing.x3),
          Text('Seats', style: context.texts.bodySmall),
          const SizedBox(height: AppSpacing.x1),
          Row(
            children: [
              Expanded(
                child: Slider(
                  // 1 to 30, which is the API's range. A slider past it would
                  // offer a refusal.
                  value: _seats.toDouble(),
                  min: 1,
                  max: 30,
                  divisions: 29,
                  label: '$_seats',
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _seats = value.round()),
                ),
              ),
              SizedBox(
                width: 32,
                child: Text('$_seats', style: context.texts.titleMedium),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x2),
          Text('Area', style: context.texts.bodySmall),
          const SizedBox(height: AppSpacing.x2),
          Wrap(
            spacing: AppSpacing.x2,
            runSpacing: AppSpacing.x2,
            children: [
              for (final area in TableArea.values)
                SelectableChip(
                  label: area.label,
                  selected: _area == area,
                  onSelected: _saving
                      ? null
                      : () => setState(() => _area = area),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.x3),
          _Field(
            label: 'Description (optional)',
            controller: _description,
            hint: 'Beside the front window',
            maxLines: 2,
          ),
          const SizedBox(height: AppSpacing.x3),
          _Field(
            label: 'Booking price in pence',
            controller: _price,
            hint: '0',
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: AppSpacing.x1),
          Text(
            // Named in pence because that is the unit, and because there is no
            // payment provider wired for a non-zero one yet.
            '0 is free. There is no card payment for table prices yet, so a '
            'charge here is informational.',
            style: context.texts.bodySmall?.copyWith(
              color: context.surfaces.inkSoft,
            ),
          ),
          const SizedBox(height: AppSpacing.x3),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _isActive,
            onChanged: _saving ? null : (on) => setState(() => _isActive = on),
            title: const Text('Customers can book it'),
          ),
          const SizedBox(height: AppSpacing.x4),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save table'),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------- sittings

class _SittingsTab extends StatelessWidget {
  const _SittingsTab({required this.state});

  final VenueState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<VenueCubit>();
    final days = state.byDay;

    return RefreshIndicator(
      onRefresh: () =>
          refreshWithSession(context, () => cubit.load(silent: true)),
      child: ListView(
        padding: pagePadding(
          context,
          top: AppSpacing.x4,
          bottom: AppSpacing.x12 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          if (state.liveTables.isEmpty)
            _Empty(
              icon: Icons.event_busy_outlined,
              title: 'Add a table first',
              body:
                  'Sittings belong to a table, so there is nothing to '
                  'schedule yet.',
            )
          else ...[
            FilledButton.icon(
              onPressed: () => _generate(context, state),
              icon: const Icon(Icons.auto_awesome, size: AppIconSize.md),
              label: const Text('Generate sittings'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            const SizedBox(height: AppSpacing.x3),
            _TableFilter(state: state),
            const SizedBox(height: AppSpacing.x4),
            if (days.isEmpty)
              _Empty(
                icon: Icons.event_note_outlined,
                title: 'Nothing scheduled',
                body:
                    'No sittings between ${_day(state.from)} and '
                    '${_day(state.to)}. Generate some — customers see an '
                    'empty day until you do.',
              )
            else
              for (final entry in days.entries) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.x2),
                  child: Text(
                    _day(entry.key),
                    style: context.texts.titleMedium,
                  ),
                ),
                for (final slot in entry.value) ...[
                  _SlotRow(slot: slot, busy: state.busyIds.contains(slot.id)),
                  const SizedBox(height: AppSpacing.x2),
                ],
                const SizedBox(height: AppSpacing.x3),
              ],
          ],
        ].revealStaggered(),
      ),
    );
  }
}

class _TableFilter extends StatelessWidget {
  const _TableFilter({required this.state});

  final VenueState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<VenueCubit>();

    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          SelectableChip(
            label: 'All tables',
            selected: state.tableFilterId == null,
            onSelected: () => cubit.filterByTable(null),
          ),
          for (final table in state.liveTables) ...[
            const SizedBox(width: AppSpacing.x2),
            SelectableChip(
              label: table.name,
              selected: state.tableFilterId == table.id,
              onSelected: () => cubit.filterByTable(table.id),
            ),
          ],
        ],
      ),
    );
  }
}

class _SlotRow extends StatelessWidget {
  const _SlotRow({required this.slot, required this.busy});

  final VenueSlot slot;
  final bool busy;

  Future<void> _delete(BuildContext context) async {
    final cubit = context.read<VenueCubit>();
    final confirmed = await _confirm(
      context,
      title: 'Delete the ${slot.timeLabel} sitting?',
      body: 'It disappears from availability for good.',
      action: 'Delete',
    );
    if (confirmed != true || !context.mounted) return;

    final error = await cubit.deleteSlot(slot.id);
    if (!context.mounted) return;
    _report(context, error);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<VenueCubit>();

    return AppSurface.row(
      padding: const EdgeInsets.all(AppSpacing.x3 + 2),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(slot.timeLabel, style: context.texts.titleMedium),
          ),
          const SizedBox(width: AppSpacing.x2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  slot.tableName,
                  style: context.texts.bodyLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  // The buffer stated, because it is why the next sitting is not
                  // where an admin expects it.
                  '${slot.durationMinutes} min'
                  '${slot.bufferMinutes > 0 ? ' + ${slot.bufferMinutes} clean' : ''}'
                  ' · free at ${slot.endsLabel}',
                  style: context.texts.bodySmall?.copyWith(
                    color: context.surfaces.inkSoft,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (slot.isBooked)
            AppChip.status(
              label: 'Booked',
              foreground: context.orderColors.ready,
              background: context.orderColors.readyContainer,
            )
          else if (!slot.isActive)
            AppChip.status(
              label: 'Closed',
              foreground: context.orderColors.overdue,
              background: context.orderColors.overdueContainer,
            ),
          PopupMenuButton<String>(
            enabled: !busy,
            icon: const Icon(Icons.more_vert, size: AppIconSize.xl),
            onSelected: (action) async {
              switch (action) {
                case 'toggle':
                  final error = await cubit.setSlotActive(
                    slot.id,
                    !slot.isActive,
                  );
                  if (!context.mounted) return;
                  _report(context, error);
                case 'delete':
                  await _delete(context);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'toggle',
                child: Text(slot.isActive ? 'Close for sale' : 'Open for sale'),
              ),
              // A held sitting cannot be deleted — the API refuses, and doing so
              // would take a table from somebody already told they have it.
              // Closing it is the move, and it is still offered above.
              if (!slot.isBooked)
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }
}

/// Bulk generation, with the preview the spacing rule makes necessary.
Future<void> _generate(BuildContext context, VenueState state) async {
  final cubit = context.read<VenueCubit>();
  await showAppSheet<void>(
    context: context,
    title: 'Generate sittings',
    subtitle: 'Existing sittings are skipped, never duplicated.',
    child: BlocProvider.value(
      value: cubit,
      child: _GenerateForm(state: state, today: cubit.today),
    ),
  );
}

class _GenerateForm extends StatefulWidget {
  const _GenerateForm({required this.state, required this.today});

  final VenueState state;

  /// The restaurant's own today, so a test can pin it.
  final DateTime today;

  @override
  State<_GenerateForm> createState() => _GenerateFormState();
}

class _GenerateFormState extends State<_GenerateForm> {
  late DateTime _from = widget.today;
  late DateTime _to = widget.today.add(const Duration(days: 30));
  String _first = '18:00';
  String _last = '21:30';
  int _turn = 90;
  int _buffer = 15;
  final _weekdays = <SlotWeekday>{};
  final _tableIds = <String>{};
  bool _busy = false;

  SlotPreview get _preview => SlotPreview.from(
    firstSitting: _first,
    lastSitting: _last,
    turnMinutes: _turn,
    bufferMinutes: _buffer,
  );

  int get _days {
    final span = _to.difference(_from).inDays + 1;
    if (_weekdays.isEmpty) return span;
    // Roughly: the exact count needs the calendar, and the API reports what it
    // actually created anyway.
    return (span * _weekdays.length / 7).round();
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _from : _to,
      firstDate: widget.today,
      // The API's 180-day ceiling on a range.
      lastDate: widget.today.add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _from = picked;
        if (_to.isBefore(_from)) _to = _from;
      } else {
        _to = picked;
      }
    });
  }

  Future<void> _pickTime({required bool isFirst}) async {
    final parts = (isFirst ? _first : _last).split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 18,
        minute: int.tryParse(parts[1]) ?? 0,
      ),
    );
    if (picked == null) return;
    final value =
        '${picked.hour.toString().padLeft(2, '0')}:'
        '${picked.minute.toString().padLeft(2, '0')}';
    setState(() => isFirst ? _first = value : _last = value);
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    final (result, error) = await context.read<VenueCubit>().generate(
      fromDate: _from,
      toDate: _to,
      firstSitting: _first,
      lastSitting: _last,
      turnMinutes: _turn,
      bufferMinutes: _buffer,
      tableIds: _tableIds.toList(),
      weekdays: _weekdays.toList(),
    );
    if (!mounted) return;
    setState(() => _busy = false);

    if (error != null) {
      AppHaptics.failure();
      showAppSnack(context, error, isError: true);
      return;
    }

    AppHaptics.success();
    Navigator.of(context).pop();
    // Both numbers, because "created 0, skipped 84" is the difference between
    // nothing happening and it already being done.
    showAppSnack(
      context,
      '${result!.created} created, ${result.skipped} already there.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    final tooMany = preview.perDay >= 24;

    return SingleChildScrollView(
      padding: pagePadding(
        context,
        top: 0,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.x4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Which dates', style: context.texts.titleMedium),
          const SizedBox(height: AppSpacing.x2),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : () => _pickDate(isFrom: true),
                  child: Text(_day(_from)),
                ),
              ),
              const SizedBox(width: AppSpacing.x2),
              const Text('to'),
              const SizedBox(width: AppSpacing.x2),
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : () => _pickDate(isFrom: false),
                  child: Text(_day(_to)),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x3),

          Text(
            'Which days (all if none picked)',
            style: context.texts.bodySmall,
          ),
          const SizedBox(height: AppSpacing.x2),
          Wrap(
            spacing: AppSpacing.x2,
            runSpacing: AppSpacing.x2,
            children: [
              for (final day in SlotWeekday.values)
                SelectableChip(
                  label: day.label,
                  selected: _weekdays.contains(day),
                  onSelected: _busy
                      ? null
                      : () => setState(() {
                          _weekdays.contains(day)
                              ? _weekdays.remove(day)
                              : _weekdays.add(day);
                        }),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.x4),

          Text(
            'Which tables (all if none picked)',
            style: context.texts.bodySmall,
          ),
          const SizedBox(height: AppSpacing.x2),
          Wrap(
            spacing: AppSpacing.x2,
            runSpacing: AppSpacing.x2,
            children: [
              for (final table in widget.state.liveTables)
                SelectableChip(
                  label: table.name,
                  selected: _tableIds.contains(table.id),
                  onSelected: _busy
                      ? null
                      : () => setState(() {
                          _tableIds.contains(table.id)
                              ? _tableIds.remove(table.id)
                              : _tableIds.add(table.id);
                        }),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.x4),

          Text('Which times', style: context.texts.titleMedium),
          const SizedBox(height: AppSpacing.x2),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : () => _pickTime(isFirst: true),
                  child: Text('First $_first'),
                ),
              ),
              const SizedBox(width: AppSpacing.x2),
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : () => _pickTime(isFirst: false),
                  child: Text('Last $_last'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x1),
          Text(
            // The single most misread field on this form.
            'Last is the latest sitting to *start*, not closing time.',
            style: context.texts.bodySmall?.copyWith(
              color: context.surfaces.inkSoft,
            ),
          ),
          const SizedBox(height: AppSpacing.x3),

          _Minutes(
            label: 'Sitting length',
            value: _turn,
            min: 15,
            max: 240,
            step: 15,
            onChanged: _busy ? null : (v) => setState(() => _turn = v),
          ),
          const SizedBox(height: AppSpacing.x2),
          _Minutes(
            label: 'Cleanup after',
            value: _buffer,
            min: 0,
            max: 120,
            step: 5,
            onChanged: _busy ? null : (v) => setState(() => _buffer = v),
          ),
          const SizedBox(height: AppSpacing.x4),

          // The reason this preview exists: spacing is length + cleanup, so
          // 90 + 15 gives 18:00, 19:45, 21:30 — not the hourly grid most people
          // picture when they fill this in.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.x3),
            decoration: BoxDecoration(
              color: tooMany
                  ? context.orderColors.overdueContainer
                  : context.surfaces.ground,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: context.surfaces.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  preview.starts.isEmpty
                      ? 'Those times produce no sittings.'
                      : '${preview.perDay} a day, per table',
                  style: context.texts.titleSmall,
                ),
                if (preview.starts.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.x1),
                  Text(
                    preview.starts.join('  ·  '),
                    style: context.texts.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.x1),
                  Text(
                    'The last table is free again at ${preview.lastEnds}. '
                    'About ${_days * preview.perDay} sittings per table over '
                    'this range.',
                    style: context.texts.bodySmall?.copyWith(
                      color: context.surfaces.inkSoft,
                    ),
                  ),
                ],
                if (tooMany) ...[
                  const SizedBox(height: AppSpacing.x1),
                  Text(
                    'The API allows 24 sittings a day at most.',
                    style: context.texts.bodySmall?.copyWith(
                      color: context.orderColors.overdue,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.x4),

          FilledButton(
            onPressed: _busy || preview.starts.isEmpty || tooMany
                ? null
                : _submit,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Generate'),
          ),
        ],
      ),
    );
  }
}

class _Minutes extends StatelessWidget {
  const _Minutes({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: context.texts.bodyMedium)),
        IconButton(
          onPressed: onChanged == null || value <= min
              ? null
              : () => onChanged!(value - step),
          icon: const Icon(Icons.remove_circle_outline),
        ),
        SizedBox(
          width: 62,
          child: Text(
            '$value min',
            textAlign: TextAlign.center,
            style: context.texts.titleSmall,
          ),
        ),
        IconButton(
          onPressed: onChanged == null || value >= max
              ? null
              : () => onChanged!(value + step),
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- shared bits

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.maxLines = 1,
    this.inputFormatters,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final int maxLines;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: context.texts.bodySmall?.copyWith(
            color: context.surfaces.inkSoft,
          ),
        ),
        const SizedBox(height: AppSpacing.x1),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          inputFormatters: inputFormatters,
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.x6),
      decoration: BoxDecoration(
        color: context.surfaces.ground,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: context.surfaces.line),
      ),
      child: Column(
        children: [
          Icon(icon, size: AppIconSize.hero, color: context.surfaces.inkSoft),
          const SizedBox(height: AppSpacing.x3),
          Text(title, style: context.texts.titleMedium),
          const SizedBox(height: AppSpacing.x1),
          Text(
            body,
            textAlign: TextAlign.center,
            style: context.texts.bodySmall?.copyWith(
              color: context.surfaces.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}

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

void _report(BuildContext context, String? error, {String? success}) {
  if (error != null) {
    AppHaptics.failure();
    // The API's own words. TABLE_HAS_BOOKINGS and SLOT_IS_BOOKED both say
    // exactly what is in the way.
    showAppSnack(context, error, isError: true);
    return;
  }
  AppHaptics.success();
  if (success != null) showAppSnack(context, success);
}

String _day(DateTime? date) {
  if (date == null) return '—';
  const months = [
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
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final difference = DateTime(
    date.year,
    date.month,
    date.day,
  ).difference(today).inDays;
  if (difference == 0) return 'Today';
  if (difference == 1) return 'Tomorrow';
  return '${date.day} ${months[date.month - 1]}';
}
