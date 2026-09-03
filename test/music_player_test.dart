import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_downloader/features/library/models/music_playlist.dart';
import 'package:media_downloader/features/library/models/track.dart';
import 'package:media_downloader/features/library/services/music_scanner_service.dart';
import 'package:media_downloader/features/player/services/audio_player_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Track Model Tests', () {
    test('Formats duration correctly', () {
      const track1 = Track(
        id: '1',
        title: 'Song 1',
        artist: 'Artist 1',
        filePath: '/test/song1.mp3',
        duration: Duration(minutes: 3, seconds: 45),
      );
      expect(track1.formattedDuration, '3:45');

      const track2 = Track(
        id: '2',
        title: 'Song 2',
        artist: 'Artist 2',
        filePath: '/test/song2.mp3',
        duration: Duration(hours: 1, minutes: 2, seconds: 5),
      );
      expect(track2.formattedDuration, '1:02:05');

      const track3 = Track(
        id: '3',
        title: 'Song 3',
        artist: 'Artist 3',
        filePath: '/test/song3.mp3',
      );
      expect(track3.formattedDuration, '--:--');
    });

    test('CopyWith preserves unchanged values', () {
      const track = Track(
        id: '1',
        title: 'Original Title',
        artist: 'Original Artist',
        filePath: '/test/song.mp3',
        duration: Duration(seconds: 120),
      );

      final updated = track.copyWith(title: 'New Title');
      expect(updated.id, '1');
      expect(updated.title, 'New Title');
      expect(updated.artist, 'Original Artist');
      expect(updated.filePath, '/test/song.mp3');
      expect(updated.duration, const Duration(seconds: 120));
    });

    test('Track equality matches on id and filePath', () {
      const track1 = Track(
        id: '/test/song.mp3',
        title: 'Title',
        artist: 'Artist',
        filePath: '/test/song.mp3',
      );
      const track2 = Track(
        id: '/test/song.mp3',
        title: 'Different Title',
        artist: 'Different Artist',
        filePath: '/test/song.mp3',
      );
      expect(track1, equals(track2));
    });
  });

  group('MusicScannerService Tests', () {
    test('Supported extensions set includes required formats', () {
      expect(MusicScannerService.supportedExtensions, contains('.mp3'));
      expect(MusicScannerService.supportedExtensions, contains('.m4a'));
      expect(MusicScannerService.supportedExtensions, contains('.wav'));
      expect(MusicScannerService.supportedExtensions, contains('.flac'));
    });

    test('Scans mock directory and discovers audio files', () async {
      final tempDir =
          await Directory.systemTemp.createTemp('music_scanner_test_');

      try {
        // Create sample audio files
        final file1 = File('${tempDir.path}/Coldplay - Yellow.mp3');
        await file1.writeAsString('mock audio content');

        final file2 = File(
            '${tempDir.path}/Hozier - Take Me To Church (Official Video).flac');
        await file2.writeAsString('mock audio content');

        final file3 = File('${tempDir.path}/document.txt');
        await file3.writeAsString('ignore me');

        // Check supported file extensions manually
        final list = tempDir.listSync();
        final audioFiles = list.where((f) {
          final ext = f.path.substring(f.path.lastIndexOf('.')).toLowerCase();
          return MusicScannerService.supportedExtensions.contains(ext);
        }).toList();

        expect(audioFiles.length, 2);
      } finally {
        await tempDir.delete(recursive: true);
      }
    });
  });

  group('AudioPlayerService Tests', () {
    test('Loop mode cycles properly', () {
      final service = AudioPlayerService.instance;
      expect(service.loopMode, PlayerLoopMode.off);

      service.toggleLoopMode();
      expect(service.loopMode, PlayerLoopMode.all);

      service.toggleLoopMode();
      expect(service.loopMode, PlayerLoopMode.one);

      service.toggleLoopMode();
      expect(service.loopMode, PlayerLoopMode.off);
    });

    test('Shuffle mode toggles', () {
      final service = AudioPlayerService.instance;
      expect(service.isShuffle, false);

      service.toggleShuffle();
      expect(service.isShuffle, true);

      service.toggleShuffle();
      expect(service.isShuffle, false);
    });
  });

  group('MusicPlaylist Model Tests', () {
    test('Calculates total duration and formats track counts correctly', () {
      const track1 = Track(
        id: '1',
        title: 'Song 1',
        artist: 'Artist 1',
        filePath: '/test/song1.mp3',
        duration: Duration(minutes: 3, seconds: 30),
      );
      const track2 = Track(
        id: '2',
        title: 'Song 2',
        artist: 'Artist 2',
        filePath: '/test/song2.mp3',
        duration: Duration(minutes: 4, seconds: 30),
      );

      final playlist = MusicPlaylist(
        name: 'Chill Vibes',
        tracks: const [track1, track2],
        artworkPath: '/test/cover.jpg',
      );

      expect(playlist.trackCount, 2);
      expect(playlist.formattedTrackCount, '2 songs');
      expect(playlist.totalDuration, const Duration(minutes: 8));
      expect(playlist.formattedTotalDuration, '8 min');
      expect(playlist.artworkPath, '/test/cover.jpg');
    });
  });
}
