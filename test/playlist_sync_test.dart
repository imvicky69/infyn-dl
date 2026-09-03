import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_downloader/core/utils/file_resolver.dart';
import 'package:media_downloader/features/downloader/models/download_format.dart';
import 'package:media_downloader/features/downloader/models/download_item.dart';
import 'package:media_downloader/features/downloader/models/playlist_metadata.dart';
import 'package:media_downloader/features/downloader/services/download_history_service.dart';
import 'package:media_downloader/features/downloader/widgets/playlist_preview_card.dart';
import 'package:media_downloader/features/library/models/library_folder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (MethodCall methodCall) async {
      return Directory.systemTemp.path;
    },
  );

  group('DownloadItem and LibraryFolder playlistUrl Tests', () {
    test('Serializes and deserializes playlistUrl in DownloadItem', () {
      final item = DownloadItem(
        id: 'item_1',
        title: 'Chaiyya Chaiyya',
        url: 'https://youtube.com/watch?v=123',
        filePath: 'C:/Downloads/item.mp3',
        format: DownloadFormat.mp3,
        quality: '320k',
        timestamp: DateTime.now(),
        playlistName: '90s Hits',
        playlistUrl: 'https://www.youtube.com/playlist?list=PL12345',
      );

      final json = item.toJson();
      expect(
          json['playlistUrl'], 'https://www.youtube.com/playlist?list=PL12345');

      final deserialized = DownloadItem.fromJson(json);
      expect(deserialized.playlistUrl,
          'https://www.youtube.com/playlist?list=PL12345');
      expect(deserialized.playlistName, '90s Hits');
    });

    test('DownloadItem copyWith respects playlistUrl and clearPlaylist', () {
      final item = DownloadItem(
        id: 'item_1',
        title: 'Track 1',
        url: 'https://youtube.com/watch?v=1',
        filePath: 'path.mp3',
        format: DownloadFormat.mp3,
        quality: '320k',
        timestamp: DateTime.now(),
        playlistName: 'Bollywood Classics',
        playlistUrl: 'https://youtube.com/playlist?list=PL999',
      );

      final updated = item.copyWith(
        playlistUrl: 'https://youtube.com/playlist?list=PLNEW',
      );
      expect(updated.playlistUrl, 'https://youtube.com/playlist?list=PLNEW');
      expect(updated.playlistName, 'Bollywood Classics');

      final cleared = item.copyWith(clearPlaylist: true);
      expect(cleared.playlistName, isNull);
      expect(cleared.playlistUrl, isNull);
    });

    test('LibraryFolder retains playlistUrl and copyWith', () {
      final folder = LibraryFolder(
        name: 'A.R. Rahman',
        folderType: LibraryFolderType.playlist,
        items: [],
        playlistUrl: 'https://youtube.com/playlist?list=PL_ARR',
      );

      expect(folder.playlistUrl, 'https://youtube.com/playlist?list=PL_ARR');
      expect(folder.isPlaylist, isTrue);

      final updated = folder.copyWith(
        playlistUrl: 'https://youtube.com/playlist?list=PL_ARR_NEW',
      );
      expect(
          updated.playlistUrl, 'https://youtube.com/playlist?list=PL_ARR_NEW');
      expect(updated.name, 'A.R. Rahman');
    });
  });

  group('DownloadHistoryService Playlist URL Persistence Tests', () {
    test('Associates, retrieves, and updates playlist URLs', () async {
      final service = DownloadHistoryService.instance;
      await service.init();

      await service.setPlaylistUrl(
        'Test Chill Playlist',
        'https://www.youtube.com/playlist?list=PL_CHILL_123',
      );

      final retrieved = await service.getPlaylistUrl('Test Chill Playlist');
      expect(retrieved, 'https://www.youtube.com/playlist?list=PL_CHILL_123');

      // Update URL
      await service.setPlaylistUrl(
        'Test Chill Playlist',
        'https://www.youtube.com/playlist?list=PL_CHILL_UPDATED',
      );
      final updated = await service.getPlaylistUrl('Test Chill Playlist');
      expect(updated, 'https://www.youtube.com/playlist?list=PL_CHILL_UPDATED');

      // Clean up
      await service.deletePlaylist(playlistName: 'Test Chill Playlist');
      final afterDelete = await service.getPlaylistUrl('Test Chill Playlist');
      expect(afterDelete, isNull);
    });
  });

  group('PlaylistPreviewCard Non-Selectable Duplicates Widget Tests', () {
    const mockPlaylist = PlaylistMetadata(
      id: 'PL_TEST',
      title: 'Workout Beats',
      uploader: 'Gym Beats',
      itemCount: 3,
      entries: [
        PlaylistEntry(
          id: 'vid_1',
          title: 'Power Track 1',
          duration: 180,
          url: 'https://youtube.com/watch?v=vid_1',
        ),
        PlaylistEntry(
          id: 'vid_2',
          title: 'Energy Track 2',
          duration: 210,
          url: 'https://youtube.com/watch?v=vid_2',
        ),
        PlaylistEntry(
          id: 'vid_3',
          title: 'Sprint Track 3',
          duration: 240,
          url: 'https://youtube.com/watch?v=vid_3',
        ),
      ],
    );

    testWidgets(
        'Displays "In Library" badge for downloaded items and excludes them from selection',
        (tester) async {
      Set<int> selected = {1}; // Index 1 is selected
      const alreadyDownloaded = {0}; // Index 0 (vid_1) is already downloaded

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return PlaylistPreviewCard(
                  playlist: mockPlaylist,
                  selectedIndices: selected,
                  alreadyDownloadedIndices: alreadyDownloaded,
                  onSelectionChanged: (newIndices) {
                    setState(() => selected = newIndices);
                  },
                );
              },
            ),
          ),
        ),
      );

      // Verify header summary shows "1 in library"
      expect(find.text('1 in library'), findsOneWidget);
      expect(find.text('1 of 3 selected'), findsOneWidget);

      // Expand playlist to see tracks
      final expandButton = find.byTooltip('View items');
      expect(expandButton, findsOneWidget);
      await tester.tap(expandButton);
      await tester.pumpAndSettle();

      // Verify "In Library" badge is visible on the downloaded item
      expect(find.text('In Library'), findsOneWidget);

      // Tap the already downloaded row (index 0) - should NOT select it
      final item1Row = find.text('Power Track 1');
      await tester.tap(item1Row);
      await tester.pumpAndSettle();
      expect(selected.contains(0), isFalse);

      // Tap unselected undownloaded row (index 2) - should select it
      final item3Row = find.text('Sprint Track 3');
      await tester.tap(item3Row);
      await tester.pumpAndSettle();
      expect(selected.contains(2), isTrue);

      // "Select All" should select only selectable items (index 1 and 2), not index 0
      final selectAllButton = find.text('Deselect All');
      // Deselect all selectable
      await tester.tap(selectAllButton);
      await tester.pumpAndSettle();
      expect(selected.isEmpty, isTrue);

      // Select All (2 selectable items: 1 and 2)
      final selectAll2 = find.text('Select All (2)');
      expect(selectAll2, findsOneWidget);
      await tester.tap(selectAll2);
      await tester.pumpAndSettle();
      expect(selected, equals({1, 2}));
      expect(selected.contains(0), isFalse);
    });
  });

  group('Missing Songs Detection Logic Tests', () {
    test(
        'Accurately identifies missing songs between online playlist and local library',
        () {
      const playlist = PlaylistMetadata(
        id: 'PL_ABC',
        title: 'Rock Legends',
        itemCount: 3,
        entries: [
          PlaylistEntry(
            id: 'v1',
            title: 'Bohemian Rhapsody',
            duration: 354,
            url: 'https://youtube.com/watch?v=v1',
          ),
          PlaylistEntry(
            id: 'v2',
            title: 'Stairway to Heaven | Remastered',
            duration: 482,
            url: 'https://youtube.com/watch?v=v2',
          ),
          PlaylistEntry(
            id: 'v3',
            title: 'Hotel California',
            duration: 390,
            url: 'https://youtube.com/watch?v=v3',
          ),
        ],
      );

      final localItems = [
        // v1 already downloaded with same url
        DownloadItem(
          id: 'dl_1',
          title: 'Bohemian Rhapsody',
          url: 'https://youtube.com/watch?v=v1',
          filePath: '/path/song1.mp3',
          format: DownloadFormat.mp3,
          quality: '320k',
          timestamp: DateTime.now(),
          playlistName: 'Rock Legends',
        ),
        // v2 already downloaded with title variance
        DownloadItem(
          id: 'dl_2',
          title: 'Stairway to Heaven (Remastered)',
          url: 'https://youtube.com/watch?v=diff_v2',
          filePath: '/path/song2.mp3',
          format: DownloadFormat.mp3,
          quality: '320k',
          timestamp: DateTime.now(),
          playlistName: 'Rock Legends',
        ),
      ];

      final missing = <PlaylistEntry>[];
      for (final entry in playlist.entries) {
        final exists = localItems.any((item) {
          if (entry.id.isNotEmpty && item.url.contains(entry.id)) return true;
          if (item.url.isNotEmpty && item.url == entry.url) return true;
          if (FileResolver.normalize(item.title) ==
              FileResolver.normalize(entry.title)) {
            return true;
          }
          return false;
        });

        if (!exists) {
          missing.add(entry);
        }
      }

      // Hotel California should be the only missing track
      expect(missing.length, equals(1));
      expect(missing.first.title, equals('Hotel California'));
      expect(missing.first.id, equals('v3'));
    });
  });
}
