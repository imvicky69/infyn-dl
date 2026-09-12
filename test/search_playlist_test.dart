import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infyn_dl/features/search/screens/search_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (MethodCall methodCall) async {
      return Directory.systemTemp.path;
    },
  );

  group('SearchScreen Playlist & Album UI Tests', () {
    testWidgets(
        'Renders search input and filter chips for Songs and Playlists & Albums',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SearchScreen(),
        ),
      );

      // Verify search input
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Search YouTube Music...'), findsOneWidget);

      // Verify filter chips
      expect(find.text('Songs'), findsOneWidget);
      expect(find.text('Playlists & Albums'), findsOneWidget);

      // Verify empty state prompt
      expect(
        find.text('Search for songs, playlists, or albums to download & play'),
        findsOneWidget,
      );

      // Switch to Playlists & Albums filter
      await tester.tap(find.text('Playlists & Albums'));
      await tester.pumpAndSettle();

      // Verify empty state is still rendered properly
      expect(
        find.text('Search for songs, playlists, or albums to download & play'),
        findsOneWidget,
      );
    });

    testWidgets(
        'Renders without overflow on narrow width (360px screen)',
        (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: SearchScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure no exceptions or RenderFlex overflow occurred
      expect(tester.takeException(), isNull);
      expect(find.text('Songs'), findsOneWidget);
      expect(find.text('Playlists & Albums'), findsOneWidget);
    });

    testWidgets(
        'Does not show "No results found" when search input contains a URL',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SearchScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Enter a playlist URL
      const url =
          'https://music.youtube.com/playlist?list=OLAK5uy_mp4ySeRG4C35llBbohNz5LEfopRN5HUnQ';
      await tester.enterText(find.byType(TextField), url);
      await tester.pump();

      // The empty state view should NOT display "No results found for"
      expect(find.textContaining('No results found for'), findsNothing);
    });
  });
}
