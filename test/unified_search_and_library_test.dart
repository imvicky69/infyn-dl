import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infyn_dl/features/library/models/music_playlist.dart';
import 'package:infyn_dl/features/library/models/track.dart';
import 'package:infyn_dl/features/library/screens/music_library_screen.dart';
import 'package:infyn_dl/features/library/services/music_scanner_service.dart';
import 'package:infyn_dl/features/search/screens/search_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SearchScreen.externalSearchQuery.value = null;
  });

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (MethodCall methodCall) async {
      return Directory.systemTemp.path;
    },
  );

  group('Unified Music Library & Search Tests', () {
    testWidgets(
        'MusicLibraryScreen searches both playlists and tracks, shows YouTube Music search prompt',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // Seed playlists and tracks in scanner
      MusicScannerService.instance.playlistsNotifier.value = [
        const MusicPlaylist(
          name: 'Bollywood Romance',
          tracks: [],
        ),
      ];
      MusicScannerService.instance.tracksNotifier.value = [
        const Track(
          id: 'test_track_1',
          title: 'Tum Hi Ho',
          artist: 'Arijit Singh',
          duration: Duration(minutes: 4, seconds: 22),
        ),
      ];

      bool navigatedToSearch = false;

      await tester.pumpWidget(
        MaterialApp(
          home: MusicLibraryScreen(
            onNavigateToSearch: () {
              navigatedToSearch = true;
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Enter search query that matches track and playlist
      final searchInput = find.byType(TextField);
      expect(searchInput, findsOneWidget);

      await tester.enterText(searchInput, 'Tum');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify YouTube Music banner appears
      expect(find.text('Search YouTube Music'), findsOneWidget);
      expect(find.textContaining('Find "Tum" online to play or download'),
          findsOneWidget);

      // Verify matching track is displayed with formatted duration
      expect(find.text('Tum Hi Ho'), findsOneWidget);
      expect(find.text('4:22'), findsOneWidget);

      // Tap the YouTube Music search banner
      await tester.tap(find.text('Search YouTube Music'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(navigatedToSearch, isTrue);
      expect(SearchScreen.externalSearchQuery.value, 'Tum');

      // Flush debounces
      await tester.pump(const Duration(seconds: 4));
    });

    test('MusicScannerService updates track duration dynamically', () {
      MusicScannerService.instance.tracksNotifier.value = [
        const Track(
          id: '/path/song.mp3',
          title: 'My Song',
          artist: 'Unknown Artist',
          filePath: '/path/song.mp3',
        ),
      ];

      expect(MusicScannerService.instance.tracks.first.duration, isNull);

      MusicScannerService.instance.updateTrackDuration(
        '/path/song.mp3',
        const Duration(minutes: 3, seconds: 15),
      );

      expect(MusicScannerService.instance.tracks.first.duration,
          const Duration(minutes: 3, seconds: 15));
      expect(MusicScannerService.instance.tracks.first.formattedDuration, '3:15');
    });

    testWidgets('SearchScreen accepts external search query and renders Paste Link button',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SearchScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify search input is present with Search YouTube Music hint
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Search YouTube Music...'), findsOneWidget);

      // Verify paste button is displayed in suffix
      expect(find.byIcon(Icons.content_paste_rounded), findsAtLeastNWidgets(1));

      // External search query listener test
      SearchScreen.externalSearchQuery.value = 'Chhoti Si Umar';
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Chhoti Si Umar'), findsOneWidget);
      expect(SearchScreen.externalSearchQuery.value, isNull);

      // Flush retry timers
      await tester.pump(const Duration(seconds: 2));
    });
  });
}
