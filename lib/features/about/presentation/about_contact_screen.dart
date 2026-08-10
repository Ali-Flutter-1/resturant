import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/animations/reveal.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/haptics/app_haptics.dart';
import '../../../shared/widgets/app_surface.dart';
import '../../../shared/widgets/app_sheet.dart';
import '../../auth/auth_cubit.dart';

/// Who the restaurant is, when it opens, and how to reach it.
///
/// Transcribed from "About & Contact Us" (`1:2727`), from the frame's
/// *metadata* only — the Figma MCP quota on this plan allows no more than a
/// call or two, so copy and geometry are the design's while every colour and
/// weight is this app's existing token, inferred rather than read off the
/// frame. Treat the styling as unverified.
///
/// From the frame: the "A Legacy of Flavor" hero, the Heritage & Vision bento
/// grid, and the "Get in Touch" contact section. The opening-hours table, map
/// panel and sign-out panel have no counterpart in it — hours and location sit
/// inside the frame's "Contact & Location Split", but as prose rather than the
/// structures used here, and signing out is an app necessity with no frame at
/// all.
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
        // As a tab root nothing is behind this screen, and
        // `automaticallyImplyLeading` adds nothing when the route cannot pop —
        // so no control appears here. Pushed instead, it gets either the
        // wired control below or the framework's BackButton. What it must
        // never show is a disabled arrow, which is what a null `onPressed`
        // handed straight to IconButton produces.
        leading: onBack == null
            ? null
            : IconButton(
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
        children: [
          const _StoryHeader(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.x6),
                // "Hero Section: Our Story" in the frame. The heading and
                // paragraph are the design's own copy; what stood here before
                // was invented while the frame was unreadable.
                Text('A Legacy of Flavor', style: context.texts.headlineLarge),
                const SizedBox(height: AppSpacing.x3),
                Text(
                  'Born from a deep respect for heritage recipes, T\'s Cafe '
                  'bridges the vibrant, aromatic traditions of Sri Lanka with '
                  'the refined cafe culture of modern Britain. Every dish '
                  'tells a story of journey, family, and culinary passion.',
                  style: context.texts.bodyLarge,
                ),
                const SizedBox(height: AppSpacing.x8),

                // "Section - Bento Grid: Heritage & Vision".
                const _BentoGrid(),
                const SizedBox(height: AppSpacing.x8),

                Text('Opening Hours', style: context.texts.headlineLarge),
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

                Text('Get in Touch', style: context.texts.headlineLarge),
                const SizedBox(height: AppSpacing.x2),
                Text(
                  'We\'d love to hear from you. Whether it\'s a catering '
                  'inquiry or just to say hello.',
                  style: context.texts.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.x4),
                const _ContactForm(),
                const SizedBox(height: AppSpacing.x8),
                const _SignOutPanel(),
              ],
            ),
          ),
        ].revealStaggered(),
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

/// "Section - Bento Grid: Heritage & Vision" — three stacked cards: two with a
/// 48pt icon tile above a heading and a paragraph, and an image-led card in
/// between whose heading sits over the photograph.
///
/// Copy and geometry are the frame's. The photograph is not exported, so the
/// image card falls back to a tinted field, on the same reasoning as the dish
/// cards elsewhere in the app.
class _BentoGrid extends StatelessWidget {
  const _BentoGrid();

  @override
  Widget build(BuildContext context) {
    // Staggered individually. As one block the three cards landed together,
    // which reads as a single slab rather than three ideas.
    return Column(
      children: [
        const _BentoCard(
          icon: Icons.eco_outlined,
          title: 'Sustainable Sourcing',
          body:
              'We partner directly with farmers in Sri Lanka and local growers '
              'in the UK to ensure every ingredient is ethically sourced, '
              'supporting communities and ensuring unparalleled freshness.',
        ),
        const SizedBox(height: AppSpacing.x2),
        const _BentoImageCard(title: 'Our Flagship Location'),
        const SizedBox(height: AppSpacing.x2),
        const _BentoCard(
          icon: Icons.diversity_3_outlined,
          title: 'Community First',
          body:
              'Beyond serving exceptional food, T\'s Cafe is designed as a '
              'gathering space—a hub for connection, conversation, and '
              'cultural exchange in the heart of the city.',
        ),
      ].revealStaggered(),
    );
  }
}

class _BentoCard extends StatelessWidget {
  const _BentoCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AppSurface.panel(
      padding: const EdgeInsets.all(AppSpacing.x6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.crimson50,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, size: AppIconSize.xl, color: scheme.primary),
          ),
          const SizedBox(height: AppSpacing.x6),
          Text(title, style: context.texts.headlineMedium),
          const SizedBox(height: AppSpacing.x3),
          Text(body, style: context.texts.bodyMedium),
        ],
      ),
    );
  }
}

/// The frame's "Card 2 (Image Focus)": a 250pt photograph with a scrim and the
/// heading resting on it.
class _BentoImageCard extends StatelessWidget {
  const _BentoImageCard({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: SizedBox(
        height: 250,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // No exported asset for this frame, so the field stands in.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.crimson100, AppColors.neutral200],
                ),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0xCC000000), Color(0x11000000)],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.x6),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  title,
                  style: context.texts.headlineMedium?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
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

    return AppSurface.row(
      padding: EdgeInsets.zero,
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
                  // The day gives way first: losing a letter of "Wednesday"
                  // costs less than losing the opening time beside it.
                  Expanded(
                    child: Text(
                      entry.day,
                      style: context.texts.bodyLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.x2),
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
                    size: AppIconSize.xxl,
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
          child: Icon(icon, size: AppIconSize.lg, color: scheme.primary),
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
                Icon(Icons.logout, size: AppIconSize.md),
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
