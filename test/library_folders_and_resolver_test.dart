import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_downloader/core/utils/file_resolver.dart';
import 'package:media_downloader/features/downloader/models/download_format.dart';
import 'package:media_downloader/features/downloader/models/download_item.dart';
import 'package:media_downloader/features/library/models/library_folder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock path_provider method channel for unit tests
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (MethodCall methodCall) async {
      return Directory.systemTemp.path;
    },
  );

  group('FileResolver Tests', () {
    test('Normalizes strings across fullwidth characters, spaces, and punctuation', () {
      const titleWithPipes =
          'Sunta Hai Mera Khuda Full Lyrical Video | Pukar | Melody Maker - A.R Rahman';
      const fileWithFullwidthPipe =
          'Sunta Hai Mera Khuda Full Lyrical Video \uFF5C Pukar \uFF5C Melody Maker - A.R Rahman.mp3';
      const fileWithSpaces =
          'Sunta Hai Mera Khuda Full Lyrical Video  Pukar  Melody Maker - A.R Rahman.mp3';

      final normTitle = FileResolver.normalize(titleWithPipes);
      final normFullwidth = FileResolver.normalize(fileWithFullwidthPipe);
      final normSpaces = FileResolver.normalize(fileWithSpaces);

      expect(normFullwidth, contains(normTitle));
      expect(normSpaces, contains(normTitle));
      expect(normFullwidth.replaceAll('mp3', ''), equals(normTitle));
    });

    test('Preserves non-Latin Unicode characters (e.g. Hindi/Urdu)', () {
      const hindiTitle = 'तू मिले दिल खिले - Kumar Sanu';
      final normalized = FileResolver.normalize(hindiTitle);
      expect(normalized, contains('तूमिलेदिलखिले'));
      expect(normalized, contains('kumarsanu'));
    });

    test('Resolves existing file on disk even when cached path has character mismatches', () async {
      final tempDir = await Directory.systemTemp.createTemp('file_resolver_test_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      // Create physical file with fullwidth pipe (\uFF5C) as yt-dlp creates
      final realFile = File(
        '${tempDir.path}${Platform.pathSeparator}Sunta Hai Mera Khuda \uFF5C Pukar.mp3',
      );
      await realFile.writeAsString('audio-bytes');

      // Create item with cached path containing spaces
      final item = DownloadItem(
        id: 'test_item_1',
        title: 'Sunta Hai Mera Khuda | Pukar',
        url: 'https://www.youtube.com/watch?v=3sULzt1AC3I',
        filePath: '${tempDir.path}${Platform.pathSeparator}Sunta Hai Mera Khuda  Pukar.mp3',
        format: DownloadFormat.mp3,
        quality: '320k',
        timestamp: DateTime.now(),
      );

      final resolved = await FileResolver.resolveFile(item);
      expect(resolved, isNotNull);
      expect(File(resolved!).existsSync(), isTrue);
      expect(resolved, equals(realFile.path));
    });
  });

  group('DownloadItem effectiveThumbnailUrl & copyWith Tests', () {
    test('Extracts YouTube thumbnail correctly from standard watch URL', () {
      final item = DownloadItem(
        id: '1',
        title: 'Test Song',
        url: 'https://www.youtube.com/watch?v=sO4mQ-l9x64',
        filePath: '',
        format: DownloadFormat.mp3,
        quality: '320k',
        timestamp: DateTime.now(),
      );

      expect(
        item.effectiveThumbnailUrl,
        equals('https://img.youtube.com/vi/sO4mQ-l9x64/mqdefault.jpg'),
      );
    });

    test('Extracts YouTube thumbnail from youtu.be short URL', () {
      final item = DownloadItem(
        id: '2',
        title: 'Short URL Song',
        url: 'https://youtu.be/3AtDnEC4zak',
        filePath: '',
        format: DownloadFormat.mp3,
        quality: '320k',
        timestamp: DateTime.now(),
      );

      expect(
        item.effectiveThumbnailUrl,
        equals('https://img.youtube.com/vi/3AtDnEC4zak/mqdefault.jpg'),
      );
    });

    test('Uses stored thumbnailUrl when explicitly provided', () {
      final item = DownloadItem(
        id: '3',
        title: 'Custom Thumb Song',
        url: 'https://www.youtube.com/watch?v=abc12345678',
        filePath: '',
        format: DownloadFormat.mp3,
        quality: '320k',
        thumbnailUrl: 'https://example.com/custom_artwork.jpg',
        timestamp: DateTime.now(),
      );

      expect(item.effectiveThumbnailUrl, equals('https://example.com/custom_artwork.jpg'));
    });

    test('copyWith updates fields and clears playlistName when requested', () {
      final item = DownloadItem(
        id: '4',
        title: 'Song',
        url: 'https://youtu.be/test1234567',
        filePath: 'C:\\path\\song.mp3',
        format: DownloadFormat.mp3,
        quality: '320k',
        playlistName: '90s Hits',
        timestamp: DateTime.now(),
      );

      final movedToUnorganized = item.copyWith(clearPlaylist: true);
      expect(movedToUnorganized.playlistName, isNull);

      final movedToNewPlaylist = item.copyWith(playlistName: 'Classics');
      expect(movedToNewPlaylist.playlistName, equals('Classics'));
    });
  });

  group('LibraryFolder Grouping Tests', () {
    test('Correctly computes stats and preview thumbnails for folder', () {
      final items = [
        DownloadItem(
          id: '1',
          title: 'Track 1',
          url: 'https://youtu.be/vid11111111',
          filePath: '',
          format: DownloadFormat.mp3,
          quality: '320k',
          fileSizeBytes: 5 * 1024 * 1024,
          timestamp: DateTime(2026, 1, 1),
          playlistName: 'Bollywood Romance',
        ),
        DownloadItem(
          id: '2',
          title: 'Track 2',
          url: 'https://youtu.be/vid22222222',
          filePath: '',
          format: DownloadFormat.mp3,
          quality: '320k',
          fileSizeBytes: 10 * 1024 * 1024,
          timestamp: DateTime(2026, 1, 2),
          playlistName: 'Bollywood Romance',
        ),
      ];

      final folder = LibraryFolder(
        name: 'Bollywood Romance',
        folderType: LibraryFolderType.playlist,
        items: items,
      );

      expect(folder.count, equals(2));
      expect(folder.audioCount, equals(2));
      expect(folder.videoCount, equals(0));
      expect(folder.formattedTotalSize, equals('15.0 MB'));
      expect(folder.previewThumbnailUrls.length, equals(2));
      expect(folder.previewThumbnailUrls[0], equals('https://img.youtube.com/vi/vid11111111/mqdefault.jpg'));
    });

    test('Unorganized and Videos folders are correctly flagged', () {
      final unorganized = LibraryFolder(
        name: 'Unorganized',
        folderType: LibraryFolderType.unorganized,
        items: const [],
      );
      expect(unorganized.isUnorganized, isTrue);
      expect(unorganized.isPlaylist, isFalse);

      final videos = LibraryFolder(
        name: 'Videos',
        folderType: LibraryFolderType.videos,
        items: const [],
      );
      expect(videos.isVideos, isTrue);
      expect(videos.isPlaylist, isFalse);
    });
  });
}
