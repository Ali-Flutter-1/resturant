import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/haptics/app_haptics.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_sheet.dart';
import '../../../shared/widgets/app_surface.dart';
import '../domain/restaurant_location.dart';

/// Where to find the restaurant.
///
/// One address, because there is one venue — so this shows it rather than
/// offering a list or an address book the customer has to maintain.
///
/// Tiles come from OpenStreetMap, which needs no API key. A Google map would
/// mean a billed key shipped in the app and a per-platform SDK setup, for a
/// static pin on a single location that never moves.
class RestaurantMapCard extends StatelessWidget {
  const RestaurantMapCard({super.key});

  static const LatLng _here = LatLng(
    RestaurantLocation.latitude,
    RestaurantLocation.longitude,
  );

  /// Opens the platform's own maps app.
  ///
  /// A geo/maps URL rather than a bundled route view: the customer already has
  /// a maps app they trust with live traffic, and duplicating it badly inside a
  /// restaurant app helps nobody.
  Future<void> _openDirections(BuildContext context) async {
    AppHaptics.toggle();
    // Apple Maps on iOS, Google Maps elsewhere; both fall back to the browser
    // if the app is missing. Built from coordinates — see the note on
    // `directionsUrl`.
    final url = RestaurantLocation.directionsUrl(
      isApple: Theme.of(context).platform == TargetPlatform.iOS,
    );

    final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      showAppSnack(
        context,
        'No maps app could be opened on this device.',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AppSurface.row(
      padding: EdgeInsets.zero,
      clip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 170,
            child: Stack(
              children: [
                FlutterMap(
                  options: const MapOptions(
                    initialCenter: _here,
                    initialZoom: 15.5,
                    // Static on purpose. This is an address, not a map the
                    // customer needs to explore — panning it away from the pin
                    // only loses them, and the Directions button hands off to a
                    // real maps app for anything more.
                    interactionOptions: InteractionOptions(
                      flags: InteractiveFlag.none,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      // OSM's tile policy asks for an identifying agent.
                      userAgentPackageName: 'com.tscafe.app',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _here,
                          width: 44,
                          height: 44,
                          // Anchored at the bottom so the pin's point sits on
                          // the coordinate rather than its middle.
                          alignment: Alignment.topCenter,
                          child: Icon(
                            Icons.place,
                            size: 44,
                            color: scheme.primary,
                            shadows: const [
                              Shadow(blurRadius: 4, color: Colors.black26),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // Tapping the map goes where the button goes, so the obvious
                // gesture is not dead.
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(onTap: () => _openDirections(context)),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.x4),
            // Stacked rather than side by side: the app's filled-button theme
            // is full width by default, and an address plus a button on one line
            // squeezes both on a narrow phone.
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  RestaurantLocation.name,
                  style: context.texts.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  RestaurantLocation.fullAddress,
                  style: context.texts.bodySmall?.copyWith(
                    color: context.surfaces.inkSoft,
                  ),
                ),
                const SizedBox(height: AppSpacing.x3),
                FilledButton.tonalIcon(
                  onPressed: () => _openDirections(context),
                  icon: const Icon(Icons.directions, size: AppIconSize.md),
                  label: const Text('Directions'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
