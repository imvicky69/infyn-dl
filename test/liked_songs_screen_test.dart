import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infyn_dl/features/library/models/music_playlist.dart';
import 'package:infyn_dl/features/library/models/track.dart';
import 'package:infyn_dl/features/library/screens/playlist_detail_screen.dart';
import 'package:infyn_dl/features/player/services/liked_songs_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LikedSongsService.instance.init();
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
    title: 'Song Alpha',
    artist: 'Artist One',
    filePath: '/path/song1.mp3',
    duration: const Duration(minutes: 3),
  );

  final testTrack2 = Track(
    id: 'track_2',
    title: 'Song Beta',
    artist: 'Artist Two',
    filePath: '/path/song2.mp3',
    duration: const Duration(minutes: 4),
  );

  testWidgets('Liked Songs screen: removes track with 1 click on heart button',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Like both tracks initially
    await LikedSongsService.instance.toggleLike(testTrack1.id);
    await LikedSongsService.instance.toggleLike(testTrack2.id);

    expect(LikedSongsService.instance.isLiked(testTrack1.id), isTrue);
    expect(LikedSongsService.instance.isLiked(testTrack2.id), isTrue);

    final playlist = MusicPlaylist(
      name: 'Liked Songs',
      tracks: [testTrack1, testTrack2],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PlaylistDetailScreen(playlist: playlist),
      ),
    );
    await tester.pumpAndSettle();

    // Verify both tracks are visible
    expect(find.text('Song Alpha'), findsOneWidget);
    expect(find.text('Song Beta'), findsOneWidget);
    expect(find.text('Playlist • 2 songs'), findsOneWidget);

    // Find the heart icon button for Song Alpha and tap it
    final heartButtons = find.byTooltip('Remove from Liked Songs');
    expect(heartButtons, findsNWidgets(2));

    await tester.tap(heartButtons.first);
    await tester.pumpAndSettle();

    // Verify Song Alpha was removed from LikedSongsService
    expect(LikedSongsService.instance.isLiked(testTrack1.id), isFalse);

    // Song Alpha is now gone from screen, Song Beta remains
    expect(find.text('Song Alpha'), findsNothing);
    expect(find.text('Song Beta'), findsOneWidget);
    expect(find.text('Playlist • 1 song'), findsOneWidget);

    // SnackBar with Undo is displayed
    expect(find.text('Removed "Song Alpha" from Liked Songs'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);

    // Tap Undo
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    // Song Alpha is restored
    expect(LikedSongsService.instance.isLiked(testTrack1.id), isTrue);
    expect(find.text('Song Alpha'), findsOneWidget);
    expect(find.text('Playlist • 2 songs'), findsOneWidget);

    // Flush AudioPlayerService debounce state-persist timer
    await tester.pump(const Duration(seconds: 4));
  });
}
