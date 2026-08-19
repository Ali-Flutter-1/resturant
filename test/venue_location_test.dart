import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:practice/core/theme/app_theme.dart';
import 'package:practice/features/about/presentation/about_contact_screen.dart';
import 'package:practice/features/auth/presentation/profile_screen.dart';
import 'package:practice/features/contact/domain/contact_repository.dart';
import 'package:practice/features/venue/domain/restaurant_location.dart';
import 'package:practice/features/venue/presentation/restaurant_map_card.dart';

import 'support/auth_fixtures.dart';
import 'support/fake_contact_repository.dart';

/// Where the restaurant is.
void main() {
  group('the directions link', () {
    test('routes to coordinates, never to a text address', () {
      // The bug this fixes: a text query has to be geocoded, and when it cannot
      // be — a placeholder address, a new venue, a typo — Apple and Google Maps
      // quietly show the user their *own* location instead. Coordinates always
      // resolve.
      final apple = RestaurantLocation.directionsUrl(isApple: true);
      expect(apple.host, 'maps.apple.com');
      expect(
        apple.queryParameters['daddr'],
        '${RestaurantLocation.latitude},${RestaurantLocation.longitude}',
      );
      expect(apple.toString(), isNot(contains('Heritage')));

      final google = RestaurantLocation.directionsUrl(isApple: false);
      expect(google.host, 'www.google.com');
      expect(
        google.queryParameters['destination'],
        '${RestaurantLocation.latitude},${RestaurantLocation.longitude}',
      );
      expect(google.toString(), isNot(contains('Heritage')));
    });

    test('the venue is the destination, not the subject of a search', () {
      // `daddr` / `destination` mean "route me there". A plain `q=` search is
      // what produced a map centred on the user with nowhere to go.
      expect(
        RestaurantLocation.directionsUrl(isApple: true).queryParameters,
        contains('daddr'),
      );
      expect(
        RestaurantLocation.directionsUrl(isApple: false).path,
        contains('/dir/'),
      );
    });

    test('one address, defined once', () {
      expect(
        RestaurantLocation.fullAddress,
        '${RestaurantLocation.addressLine}, '
        '${RestaurantLocation.city} ${RestaurantLocation.postcode}',
      );
    });
  });

  group('where the map appears', () {
    testWidgets('on About & Contact, which only customers reach', (
      tester,
    ) async {
      final view = tester.view;
      view.physicalSize = const Size(390, 3000);
      view.devicePixelRatio = 1.0;
      addTearDown(view.resetPhysicalSize);
      addTearDown(view.resetDevicePixelRatio);

      await tester.pumpWidget(
        BlocProvider(
          create: (_) => AuthFixtures.cubit(AuthFixtures.customer),
          child: RepositoryProvider<ContactRepository>(
            create: (_) => FakeContactRepository(),
            // The app theme, because every surface reads the `AppSurfaces`
            // extension from it.
            child: MaterialApp(
              theme: AppTheme.light,
              home: const AboutContactScreen(),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(RestaurantMapCard), findsOneWidget);
      expect(find.text(RestaurantLocation.fullAddress), findsOneWidget);
    });

    testWidgets('and nowhere on the profile, whatever the role', (
      tester,
    ) async {
      final view = tester.view;
      view.physicalSize = const Size(390, 2400);
      view.devicePixelRatio = 1.0;
      addTearDown(view.resetPhysicalSize);
      addTearDown(view.resetDevicePixelRatio);

      for (final user in [
        AuthFixtures.customer,
        AuthFixtures.staff,
        AuthFixtures.admin,
      ]) {
        await tester.pumpWidget(
          BlocProvider(
            key: ValueKey(user.role),
            create: (_) => AuthFixtures.cubit(user),
            child: MaterialApp(
              theme: AppTheme.light,
              home: const ProfileScreen(),
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 2));

        // The profile is the person's own account. The venue address belongs
        // with the rest of the contact details, not repeated here.
        expect(
          find.byType(RestaurantMapCard),
          findsNothing,
          reason: 'map leaked onto the ${user.role.name} profile',
        );
      }
    });
  });
}
