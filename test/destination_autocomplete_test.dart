import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:journey_guard_ai/models/place_suggestion.dart';
import 'package:journey_guard_ai/services/routing_service.dart';
import 'package:journey_guard_ai/screens/main/tabs/lovable_home_tab.dart';

void main() {
  group('Destination Autocomplete & Nominatim OpenStreetMap Tests', () {
    final routingService = RoutingService();

    test('PlaceSuggestion.fromNominatim parses OpenStreetMap JSON cleanly', () {
      final json = {
        'place_id': 1001,
        'lat': '10.0889333',
        'lon': '77.0595248',
        'name': 'Munnar',
        'display_name': 'Munnar, Devikulam, Idukki, Kerala, 685612, India',
        'address': {
          'town': 'Munnar',
          'county': 'Devikulam',
          'state_district': 'Idukki',
          'state': 'Kerala',
          'country': 'India',
        },
        'type': 'town',
      };

      final suggestion = PlaceSuggestion.fromNominatim(json);

      expect(suggestion.name, equals('Munnar'));
      expect(suggestion.districtState, contains('Idukki'));
      expect(suggestion.districtState, contains('Kerala'));
      expect(suggestion.latitude, closeTo(10.0889, 0.001));
      expect(suggestion.longitude, closeTo(77.0595, 0.001));
      expect(suggestion.latLng.latitude, closeTo(10.0889, 0.001));
      expect(suggestion.latLng.longitude, closeTo(77.0595, 0.001));
    });

    test('PlaceSuggestion.fromNominatim handles missing name by splitting display_name', () {
      final json = {
        'place_id': 1002,
        'lat': '9.0196',
        'lon': '76.9248',
        'display_name': 'Punalur, Pathanapuram, Kollam, Kerala, India',
        'address': {
          'county': 'Pathanapuram',
          'state_district': 'Kollam',
          'state': 'Kerala',
        },
        'type': 'town',
      };

      final suggestion = PlaceSuggestion.fromNominatim(json);

      expect(suggestion.name, equals('Punalur'));
      expect(suggestion.districtState, contains('Kollam'));
      expect(suggestion.latitude, closeTo(9.0196, 0.001));
    });

    test('searchPlaceSuggestions ignores short queries (< 2 chars)', () async {
      final results1 = await routingService.searchPlaceSuggestions('');
      final results2 = await routingService.searchPlaceSuggestions('M');

      expect(results1, isEmpty);
      expect(results2, isEmpty);
    });

    test('searchPlaceSuggestions fetches matching places for 2–3 character prefixes', () async {
      final results = await routingService.searchPlaceSuggestions('Mu');
      expect(results.isNotEmpty, isTrue);
      expect(results.any((r) => r.name.toLowerCase().contains('munnar')), isTrue);

      final koResults = await routingService.searchPlaceSuggestions('Ko');
      expect(koResults.isNotEmpty, isTrue);
      expect(koResults.any((r) => r.name.toLowerCase().contains('kochi') || r.name.toLowerCase().contains('kollam')), isTrue);
    });

    group('Required Test Places Resolve Successfully with Coordinates & Subtitles', () {
      final requiredPlaces = [
        'Munnar',
        'Kochi International Airport',
        'Punalur',
        'Kollam',
        'Thiruvananthapuram',
        'Alappuzha',
        'Idukki',
      ];

      for (final place in requiredPlaces) {
        test('Searches and resolves "$place"', () async {
          final results = await routingService.searchPlaceSuggestions(place);

          expect(results.isNotEmpty, isTrue, reason: 'Expected results for $place');
          final match = results.firstWhere(
            (r) => r.name.toLowerCase().contains(place.toLowerCase()) ||
                place.toLowerCase().contains(r.name.toLowerCase()),
            orElse: () => results.first,
          );

          expect(match.name.isNotEmpty, isTrue);
          expect(match.districtState.isNotEmpty, isTrue);
          expect(match.latitude, isNot(0.0));
          expect(match.longitude, isNot(0.0));
        });
      }
    });

    test('geocodePlace returns valid LatLng for known landmark', () async {
      final munnarLoc = await routingService.geocodePlace('Munnar');
      expect(munnarLoc, isNotNull);
      expect(munnarLoc!.latitude, closeTo(10.0889, 0.05));
      expect(munnarLoc.longitude, closeTo(77.0595, 0.05));

      final airportLoc = await routingService.geocodePlace('Kochi International Airport');
      expect(airportLoc, isNotNull);
      expect(airportLoc!.latitude, closeTo(10.1520, 0.05));
      expect(airportLoc.longitude, closeTo(76.3922, 0.05));
    });

    test('searchPlaces returns raw map format for backward compatibility', () async {
      final rawMaps = await routingService.searchPlaces('Punalur');
      expect(rawMaps.isNotEmpty, isTrue);
      expect(rawMaps.first, contains('name'));
      expect(rawMaps.first, contains('district_state'));
      expect(rawMaps.first, contains('lat'));
      expect(rawMaps.first, contains('lon'));
    });
  });

  group('LovableHomeTab Destination Autocomplete Widget Tests', () {
    testWidgets('Renders destination input and shows autocomplete dropdown on typing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LovableHomeTab(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the Destination TextField by hint
      final destinationFinder = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText?.contains('destination') == true,
      );
      expect(destinationFinder, findsOneWidget);

      // Enter "Munnar" into destination
      await tester.enterText(destinationFinder, 'Munnar');
      await tester.pump();

      // Wait 350ms for the 300ms debounce timer to fire
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      // Verify suggestions dropdown appears with place name and district
      expect(find.text('Munnar'), findsWidgets);
      expect(find.textContaining('Idukki'), findsWidgets);
      expect(find.byIcon(Icons.location_on_outlined), findsWidgets);

      // Tap on the "Munnar" suggestion tile
      final munnarTile = find.widgetWithText(ListTile, 'Munnar').first;
      await tester.tap(munnarTile);
      await tester.pumpAndSettle();

      // Verify the destination field is updated
      final updatedTextField = tester.widget<TextField>(destinationFinder);
      expect(updatedTextField.controller?.text, equals('Munnar'));

      // Dropdown should be dismissed
      expect(find.byType(ListTile), findsNothing);
    });

    testWidgets('Shows "No places found" when search returns empty results', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LovableHomeTab(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final destinationFinder = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText?.contains('destination') == true,
      );
      expect(destinationFinder, findsOneWidget);

      // Enter a nonexistent query
      await tester.enterText(destinationFinder, 'ZzQxNonExistentPlace9999');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      // Verify "No places found" appears
      expect(find.text('No places found'), findsOneWidget);
      expect(find.byIcon(Icons.search_off_rounded), findsOneWidget);
    });
  });
}
