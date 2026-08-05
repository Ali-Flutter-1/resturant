import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/animations/motion.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/haptics/app_haptics.dart';
import '../../../shared/widgets/app_sheet.dart';
import '../../auth/auth_cubit.dart';

/// The restaurant's story, hours, and how to reach it.
///
/// NOT transcribed from Figma — the MCP quota was exhausted before
/// "About & Contact Us" (`1:2727`, 390×3229) could be read. The frame is over
/// three times the height of a phone screen, so it certainly carries more
/// than this. Treat this as a structural stand-in and reconcile it with the
/// design before shipping.
class AboutContactScreen extends StatelessWidget {
  const AboutContactScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  static const _hours = [
    (day: 'Monday', hours: 'Closed'),
    (day: 'Tuesday — Thursday', hours: '17:00 — 22:30'),
    (day: 'Friday — Saturday', hours: '12:00 — 23:00'),
    (day: 'Sunday', hours: '12:00 — 21:00'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: onBack,
          tooltip: 'Back',
        ),
        title: const Text('About & Contact'),
      ),
      body: ListView(
        padding: EdgeInsets.only(
          bottom: AppSpacing.x8 + MediaQuery.paddingOf(context).bottom,
        ),
        children:
            [
                  const _StoryHeader(),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.gutter,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: AppSpacing.x6),
                        Text('Our Story', style: context.texts.headlineLarge),
                        const SizedBox(height: AppSpacing.x3),
                        Text(
                          "T's Café began as a family kitchen in Colombo and found its "
                          'second home in London. Every dish on the menu carries both '
                          'places: Sri Lankan spice work learned across three '
                          'generations, cooked with British produce and served the way '
                          'we would serve it at home.',
                          style: context.texts.bodyLarge,
                        ),
                        const SizedBox(height: AppSpacing.x8),

                        Text(
                          'Opening Hours',
                          style: context.texts.headlineLarge,
                        ),
                        const SizedBox(height: AppSpacing.x3),
                        _HoursTable(hours: _hours),
                        const SizedBox(height: AppSpacing.x8),

                        Text('Find Us', style: context.texts.headlineLarge),
                        const SizedBox(height: AppSpacing.x3),
                        const _MapPanel(),
                        const SizedBox(height: AppSpacing.x4),

                        const _ContactRow(
                          icon: Icons.place_outlined,
                          label: 'Address',
                          value: '128 Heritage Lane, London SW1A 1AA',
                        ),
                        const SizedBox(height: AppSpacing.x3),
                        const _ContactRow(
                          icon: Icons.call_outlined,
                          label: 'Phone',
                          value: '+44 20 7946 0958',
                        ),
                        const SizedBox(height: AppSpacing.x3),
                        const _ContactRow(
                          icon: Icons.mail_outline,
                          label: 'Email',
                          value: 'hello@tscafe.co.uk',
                        ),
                        const SizedBox(height: AppSpacing.x8),

                        Text(
                          'Send a Message',
                          style: context.texts.headlineLarge,
                        ),
                        const SizedBox(height: AppSpacing.x3),
                        const _ContactForm(),
                        const SizedBox(height: AppSpacing.x8),
                        const _SignOutPanel(),
                      ],
                    ),
                  ),
                ]
                .animate(interval: 60.ms)
                .fadeIn(duration: Motion.moderate)
                .slideY(begin: 0.05, end: 0, curve: Motion.enter),
      ),
    );
  }
}

class _StoryHeader extends StatelessWidget {
  const _StoryHeader();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/welcome_hero.jpg', fit: BoxFit.cover),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color(0xD9000000), Color(0x40000000)],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.gutter),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Heritage in Every Bite',
                  style: context.texts.displayLarge?.copyWith(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: AppSpacing.x1),
                Text(
                  'British & Sri Lankan · Est. 2011',
                  style: context.texts.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HoursTable extends StatelessWidget {
  const _HoursTable({required this.hours});

  final List<({String day, String hours})> hours;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: context.surfaces.restShadow,
      ),
      child: Column(
        children: [
          for (final (index, entry) in hours.indexed) ...[
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.x4,
                vertical: AppSpacing.x3,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(entry.day, style: context.texts.bodyLarge),
                  Text(
                    entry.hours,
                    style: context.texts.titleMedium?.copyWith(
                      color: entry.hours == 'Closed'
                          ? context.surfaces.inkSoft
                          : scheme.onSurface,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            if (index != hours.length - 1) const Divider(),
          ],
        ],
      ),
    );
  }
}

/// Stands in for the map. No mapping SDK is in the project and none should be
/// chosen without knowing which provider the business already pays for.
class _MapPanel extends StatelessWidget {
  const _MapPanel();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        height: 160,
        color: context.surfaces.ground,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: _StreetGridPainter(context.surfaces.line)),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.place,
                    size: 30,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: AppSpacing.x1),
                  Text('Map to be wired up', style: context.texts.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StreetGridPainter extends CustomPainter {
  const _StreetGridPainter(this.colour);

  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = colour
      ..strokeWidth = 1;

    for (var x = 0.0; x < size.width; x += 32) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += 32) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_StreetGridPainter oldDelegate) =>
      oldDelegate.colour != colour;
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: context.surfaces.accentContainer,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(icon, size: 18, color: scheme.primary),
        ),
        const SizedBox(width: AppSpacing.x3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: AppTypography.caption(context.surfaces.inkSoft),
              ),
              const SizedBox(height: 2),
              Text(value, style: context.texts.bodyLarge),
            ],
          ),
        ),
      ],
    );
  }
}

class _ContactForm extends StatefulWidget {
  const _ContactForm();

  @override
  State<_ContactForm> createState() => _ContactFormState();
}

class _ContactFormState extends State<_ContactForm> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _message = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _message.dispose();
    super.dispose();
  }

  void _send() {
    FocusScope.of(context).unfocus();

    // Checked here rather than server-side, so the user is told what is
    // missing before anything is sent.
    if (_name.text.trim().isEmpty || _message.text.trim().isEmpty) {
      showAppSnack(
        context,
        'Add your name and a message so we can reply.',
        isError: true,
      );
      return;
    }
    if (!_email.text.contains('@') || !_email.text.contains('.')) {
      showAppSnack(
        context,
        'That email address looks incomplete.',
        isError: true,
      );
      return;
    }

    _name.clear();
    _email.clear();
    _message.clear();
    showAppSnack(context, 'Message sent — we usually reply within a day.');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Your name'),
        ),
        const SizedBox(height: AppSpacing.x3),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: const InputDecoration(hintText: 'Email address'),
        ),
        const SizedBox(height: AppSpacing.x3),
        TextField(
          controller: _message,
          maxLines: 4,
          decoration: const InputDecoration(hintText: 'How can we help?'),
        ),
        const SizedBox(height: AppSpacing.x4),
        FilledButton(onPressed: _send, child: const Text('Send Message')),
      ],
    );
  }
}

/// Temporary, alongside the mock auth. Profile has no designed frame; this
/// sits at the bottom of About so a role can be swapped without restarting.
class _SignOutPanel extends StatelessWidget {
  const _SignOutPanel();

  @override
  Widget build(BuildContext context) {
    final email = context.select((AuthCubit c) => c.state.email);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: context.surfaces.ground,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: context.surfaces.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SIGNED IN AS',
            style: AppTypography.caption(context.surfaces.inkSoft),
          ),
          const SizedBox(height: AppSpacing.x1),
          Text(email ?? 'Unknown', style: context.texts.bodyLarge),
          const SizedBox(height: AppSpacing.x4),
          OutlinedButton(
            onPressed: () {
              AppHaptics.commit();
              context.read<AuthCubit>().signOut();
            },
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.logout, size: 17),
                SizedBox(width: AppSpacing.x2),
                Text('Sign out'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
