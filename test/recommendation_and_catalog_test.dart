import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infyn_dl/features/home/models/catalog_playlist.dart';
import 'package:infyn_dl/features/home/models/user_preferences.dart';
import 'package:infyn_dl/features/home/services/catalog_service.dart';
import 'package:infyn_dl/features/home/services/recommendation_service.dart';
import 'package:infyn_dl/features/home/services/user_preferences_service.dart';
import 'package:infyn_dl/features/library/models/track.dart';
import 'package:infyn_dl/features/library/screens/music_library_screen.dart';
import 'package:infyn_dl/features/player/services/recently_played_service.dart';
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

  group('CatalogPlaylist Model & URL Extraction Tests', () {
    test(
        'Correctly extracts playlist ID from full YouTube Music and YouTube URLs',
        () {
      // 1. YouTube Music URL
      final ytmJson = {
        'id': 'ytm_playlist',
        'title': 'YouTube Music Hits',
        'url':
            'https://music.youtube.com/playlist?list=RDCLAK5uy_kfdjhf8723&si=123',
        'description': 'Top YTM tracks',
        'genres': ['Pop'],
        'languages': ['English'],
        'moods': ['Energize'],
        'tags': ['hits'],
        'featured': true,
      };
      final ytmPlaylist = CatalogPlaylist.fromJson(ytmJson);
      expect(ytmPlaylist, isNotNull);
      expect(ytmPlaylist!.youtubeId, 'RDCLAK5uy_kfdjhf8723');
      expect(ytmPlaylist.musicYoutubeUrl,
          'https://music.youtube.com/playlist?list=RDCLAK5uy_kfdjhf8723');

      // 2. Standard YouTube URL
      final ytJson = {
        'id': 'yt_playlist',
        'title': 'YouTube Classical',
        'url':
            'https://www.youtube.com/playlist?list=PL4fGSIFgk54NqK0w7zY3E1P8g5',
        'description': 'Peaceful classics',
        'genres': ['Classical'],
        'languages': ['Instrumental'],
        'featured': false,
      };
      final ytPlaylist = CatalogPlaylist.fromJson(ytJson);
      expect(ytPlaylist, isNotNull);
      expect(ytPlaylist!.youtubeId, 'PL4fGSIFgk54NqK0w7zY3E1P8g5');
      expect(ytPlaylist.youtubeUrl,
          'https://www.youtube.com/playlist?list=PL4fGSIFgk54NqK0w7zY3E1P8g5');

      // 3. Backwards compatibility: youtubeId fallback
      final legacyJson = {
        'id': 'legacy_playlist',
        'title': 'Legacy Beats',
        'youtubeId': 'PL1234567890',
      };
      final legacyPlaylist = CatalogPlaylist.fromJson(legacyJson);
      expect(legacyPlaylist, isNotNull);
      expect(legacyPlaylist!.youtubeId, 'PL1234567890');
      expect(legacyPlaylist.url,
          'https://www.youtube.com/playlist?list=PL1234567890');

      // 4. Converts to SearchPlaylistInfo seamlessly
      final searchInfo = ytmPlaylist.toSearchPlaylistInfo();
      expect(searchInfo.id, 'RDCLAK5uy_kfdjhf8723');
      expect(searchInfo.title, 'YouTube Music Hits');
      expect(searchInfo.genres, ['Pop']);

      // 5. Rejects invalid entries
      expect(
          CatalogPlaylist.fromJson(
              {'id': '', 'title': 'T', 'url': 'https://...'}),
          isNull);
      expect(
          CatalogPlaylist.fromJson(
              {'id': '1', 'title': '', 'url': 'https://...'}),
          isNull);
      expect(CatalogPlaylist.fromJson({'id': '1', 'title': 'T', 'url': ''}),
          isNull);
    });
  });

  group('UserPreferencesService Tests', () {
    test('Persists and restores user preferences correctly', () async {
      final prefService = UserPreferencesService.instance;
      await prefService.init();

      expect(prefService.preferences.isEmpty, isTrue);
      expect(prefService.preferences.isOnboarded, isFalse);

      await prefService.updatePreferences(
        const UserPreferences(
          languages: ['Hindi', 'English'],
          genres: ['Lo-Fi', 'Bollywood'],
          moods: ['Chill', 'Focus'],
          isOnboarded: true,
        ),
      );

      expect(prefService.preferences.languages, ['Hindi', 'English']);
      expect(prefService.preferences.genres, ['Lo-Fi', 'Bollywood']);
      expect(prefService.preferences.moods, ['Chill', 'Focus']);
      expect(prefService.preferences.isOnboarded, isTrue);
      expect(prefService.preferences.isEmpty, isFalse);
    });
  });

  group('RecommendationService Ranking Tests', () {
    test('Scores playlists according to language, genre, and mood matches', () {
      final recService = RecommendationService.instance;
      const userPrefs = UserPreferences(
        languages: ['Hindi'],
        genres: ['Bollywood', 'Romantic'],
        moods: ['Relax'],
      );

      const bollywoodPlaylist = CatalogPlaylist(
        id: 'p1',
        title: 'Bollywood Romance',
        url: 'https://www.youtube.com/playlist?list=PL1',
        genres: ['Bollywood', 'Romantic'],
        languages: ['Hindi'],
        moods: ['Relax'],
        featured: true,
      );

      const edmPlaylist = CatalogPlaylist(
        id: 'p2',
        title: 'EDM Festival',
        url: 'https://www.youtube.com/playlist?list=PL2',
        genres: ['Electronic', 'House'],
        languages: ['English'],
        moods: ['Party'],
        featured: false,
      );

      // Bollywood matches Hindi (+30), Bollywood (+25), Romantic (+25), Relax (+15), Featured (+10)
      final scoreBollywood = recService.computeScore(
        playlist: bollywoodPlaylist,
        preferences: userPrefs,
        downloadedPlaylistNames: {},
        diversitySeed: 0,
      );

      // EDM matches nothing
      final scoreEdm = recService.computeScore(
        playlist: edmPlaylist,
        preferences: userPrefs,
        downloadedPlaylistNames: {},
        diversitySeed: 0,
      );

      expect(scoreBollywood, greaterThan(scoreEdm + 80));

      // Downloaded penalty test
      final scoreDownloaded = recService.computeScore(
        playlist: bollywoodPlaylist,
        preferences: userPrefs,
        downloadedPlaylistNames: {'bollywood romance'},
        diversitySeed: 0,
      );
      expect(scoreDownloaded, equals(scoreBollywood - 25));
    });
  });

  group('MusicLibraryScreen Unified Layout Widget Tests', () {
    testWidgets('Renders downloaded music on top with Featured Playlists below',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await CatalogService.instance.init();

      await tester.pumpWidget(
        const MaterialApp(
          home: MusicLibraryScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify top local library controls
      expect(find.text('Music Library'), findsOneWidget);
      expect(find.text('Playlists'), findsOneWidget);
      expect(find.text('Tracks'), findsOneWidget);
      expect(find.text('Liked Songs'), findsOneWidget);

      // Verify Featured Playlists section is mounted cleanly below local music
      expect(find.text('Featured Playlists'), findsOneWidget);
      expect(find.text('Curated for you • Tap to preview & download'),
          findsOneWidget);

      // Verify the 4 curated playlists are present
      expect(find.text('Mellow Pop Classics'), findsOneWidget);
      expect(find.text('00s Bollywood Romance'), findsOneWidget);
      expect(find.text('An Unspoken Chronicle'), findsOneWidget);
      expect(find.text('90s Bollywood Romance'), findsOneWidget);

      // Verify NO horizontal scrolling ListView in Featured Playlists
      final horizontalLists = find.byWidgetPredicate(
        (widget) =>
            widget is ListView && widget.scrollDirection == Axis.horizontal,
      );
      expect(horizontalLists, findsNothing);
    });
  });

  group('RecentlyPlayedService Tests', () {
    test('Adds track, moves to front, deduplicates, and caps at 30 items',
        () async {
      final service = RecentlyPlayedService.instance;
      await service.clearHistory();

      expect(service.recentlyPlayed.isEmpty, isTrue);

      // Add track 1
      const track1 = Track(id: 't1', title: 'Song One', artist: 'Artist A');
      await service.addTrack(track1);
      expect(service.recentlyPlayed.length, 1);
      expect(service.recentlyPlayed.first.id, 't1');

      // Add track 2
      const track2 = Track(id: 't2', title: 'Song Two', artist: 'Artist B');
      await service.addTrack(track2);
      expect(service.recentlyPlayed.length, 2);
      expect(service.recentlyPlayed.first.id, 't2');

      // Re-add track 1 (should move to front, not duplicate)
      await service.addTrack(track1);
      expect(service.recentlyPlayed.length, 2);
      expect(service.recentlyPlayed.first.id, 't1');

      // Add 35 unique tracks to verify 30-item cap
      for (int i = 0; i < 35; i++) {
        await service
            .addTrack(Track(id: 'bulk_$i', title: 'Song $i', artist: 'Artist'));
      }
      expect(service.recentlyPlayed.length, 30);
      expect(service.recentlyPlayed.first.id, 'bulk_34');
    });
  });
}
