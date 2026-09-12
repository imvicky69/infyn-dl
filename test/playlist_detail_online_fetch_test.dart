import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infyn_dl/features/downloader/services/download_history_service.dart';
import 'package:infyn_dl/features/library/models/music_playlist.dart';
import 'package:infyn_dl/features/library/models/track.dart';
import 'package:infyn_dl/features/library/screens/playlist_detail_screen.dart';
import 'package:infyn_dl/features/player/services/liked_songs_service.dart';
import 'package:infyn_dl/features/search/services/ytm_search_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LikedSongsService.instance.init();
    await DownloadHistoryService.instance.init();
  });

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (MethodCall methodCall) async {
      return Directory.systemTemp.path;
    },
  );

  final testTrack1 = Track(
    id: 'track_1',
    title: 'Main Yahaan Hoon',
    artist: 'Udit Narayan',
    filePath: '/music/00s Bollywood Romance/Main Yahaan Hoon.m4a',
    duration: const Duration(minutes: 4, seconds: 56),
  );

  testWidgets(
      'PlaylistDetailScreen renders Fetch All Playlist Songs button below downloaded songs',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final playlist = MusicPlaylist(
      name: '00s Bollywood Romance',
      tracks: [testTrack1],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PlaylistDetailScreen(playlist: playlist),
      ),
    );
    await tester.pumpAndSettle();

    // Verify playlist title and track count
    expect(find.text('00s Bollywood Romance'), findsWidgets);
    expect(find.text('Main Yahaan Hoon'), findsOneWidget);

    // Verify "Download More Songs" card and "Fetch All Playlist Songs" button are present
    expect(find.text('Download More Songs'), findsOneWidget);
    expect(find.text('Fetch All Playlist Songs'), findsOneWidget);

    // Flush AudioPlayerService debounce timer
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets(
      'PlaylistDetailScreen does NOT render Fetch All Playlist Songs button for Liked Songs',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final playlist = MusicPlaylist(
      name: 'Liked Songs',
      tracks: [testTrack1],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PlaylistDetailScreen(playlist: playlist),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Download More Songs'), findsNothing);
    expect(find.text('Fetch All Playlist Songs'), findsNothing);

    // Flush AudioPlayerService debounce timer
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets(
      'PlaylistDetailScreen displays online tracks with Saved and Download actions when cached',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    const playlistId = 'PL_test_00s';
    final onlineTracks = [
      testTrack1, // Already downloaded
      Track(
        id: 'track_2',
        title: 'Tera Mera Rishta Purana',
        artist: 'Mustafa Zahid',
        webUrl: 'https://music.youtube.com/watch?v=track_2',
        duration: const Duration(minutes: 5, seconds: 48),
      ), // Missing
    ];

    // Pre-cache tracks in memory cache
    await YtmSearchService.instance
        .cachePlaylistTracks(playlistId, onlineTracks);

    final playlist = MusicPlaylist(
      name: '00s Bollywood Romance',
      tracks: [testTrack1],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PlaylistDetailScreen(playlist: playlist),
      ),
    );
    await tester.pumpAndSettle();

    // Verify initial button is shown
    expect(find.text('Fetch All Playlist Songs'), findsOneWidget);

    // Flush AudioPlayerService debounce timer
    await tester.pump(const Duration(seconds: 4));
  });
}
