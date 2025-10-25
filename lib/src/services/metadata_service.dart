import 'dart:io';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:path/path.dart' as path;

/// Service for copying metadata from one media file to another
class MetadataService {
  /// Copies metadata (including album art) from source file to destination file
  ///
  /// Supports: mp3, mp4, flac, ogg, opus, wav
  ///
  /// Returns true if metadata was successfully copied, false otherwise
  static Future<bool> copyMetadata(File sourceFile, File destinationFile) async {
    try {
      // Check if both files exist
      if (!await sourceFile.exists()) {
        print('[MetadataService] Source file does not exist: ${sourceFile.path}');
        return false;
      }

      if (!await destinationFile.exists()) {
        print('[MetadataService] Destination file does not exist: ${destinationFile.path}');
        return false;
      }

      // Get file extensions
      final sourceExt = path.extension(sourceFile.path).toLowerCase();
      final destExt = path.extension(destinationFile.path).toLowerCase();

      // Only copy metadata between same file types
      if (sourceExt != destExt) {
        print('[MetadataService] File types differ, skipping metadata copy');
        return false;
      }

      // Check if the format is supported
      final supportedFormats = ['.mp3', '.mp4', '.m4a', '.flac', '.ogg', '.opus', '.wav'];
      if (!supportedFormats.contains(sourceExt)) {
        print('[MetadataService] Unsupported format: $sourceExt');
        return false;
      }

      print('[MetadataService] Reading metadata from: ${sourceFile.path}');

      // Read metadata from source file using AudioMetadata (universal)
      final sourceMetadata = await readMetadata(sourceFile, getImage: true);

      if (sourceMetadata == null) {
        print('[MetadataService] No metadata found in source file');
        return false;
      }

      print('[MetadataService] Metadata read successfully, writing to: ${destinationFile.path}');

      // Log what was read from source using universal AudioMetadata properties
      final pictureCount = sourceMetadata.pictures.length;
      print('[MetadataService] Source has $pictureCount album art(s)');

      // Update destination file metadata
      updateMetadata(
        destinationFile,
        (destMetadata) {
          // Copy from AudioMetadata to format-specific ParserTag
          _copyFromAudioMetadata(sourceMetadata, destMetadata);
        },
      );

      print('[MetadataService] Metadata copied successfully');
      return true;
    } catch (e, stackTrace) {
      print('[MetadataService] Error copying metadata: $e');
      print('[MetadataService] Stack trace: $stackTrace');
      return false;
    }
  }

  /// Copy from AudioMetadata (source) to format-specific metadata (destination)
  static void _copyFromAudioMetadata(AudioMetadata source, dynamic dest) {
    // Handle each format type separately since ParserTag is format-specific
    if (dest is Mp3Metadata) {
      _copyToMp3(source, dest);
    } else if (dest is Mp4Metadata) {
      _copyToMp4(source, dest);
    } else if (dest is VorbisMetadata) {
      _copyToVorbis(source, dest);
    } else if (dest is RiffMetadata) {
      _copyToRiff(source, dest);
    } else {
      print('[MetadataService] Unsupported destination metadata type: ${dest.runtimeType}');
    }
  }

  /// Copy AudioMetadata to Mp3Metadata
  static void _copyToMp3(AudioMetadata source, Mp3Metadata dest) {
    // Copy basic metadata using AudioMetadata properties
    if (source.title != null) dest.songName = source.title;
    if (source.artist != null) dest.leadPerformer = source.artist;
    if (source.album != null) dest.album = source.album;
    if (source.year != null) dest.year = source.year?.year;
    if (source.trackNumber != null) dest.trackNumber = source.trackNumber;
    if (source.genres.isNotEmpty) dest.genres = source.genres;

    // Copy album art from universal pictures property
    if (source.pictures.isNotEmpty) {
      dest.pictures = source.pictures;
      print('[MetadataService] Copied ${source.pictures.length} album art(s) to MP3');
    } else {
      print('[MetadataService] No album art to copy to MP3');
    }
  }

  /// Copy AudioMetadata to Mp4Metadata
  static void _copyToMp4(AudioMetadata source, Mp4Metadata dest) {
    // Copy basic metadata using AudioMetadata properties
    if (source.title != null) dest.title = source.title;
    if (source.artist != null) dest.artist = source.artist;
    if (source.album != null) dest.album = source.album;
    if (source.year != null) dest.year = source.year;
    if (source.trackNumber != null) dest.trackNumber = source.trackNumber;
    if (source.trackTotal != null) dest.totalTracks = source.trackTotal;
    if (source.discNumber != null) dest.discNumber = source.discNumber;
    if (source.totalDisc != null) dest.totalDiscs = source.totalDisc;
    if (source.lyrics != null) dest.lyrics = source.lyrics;
    if (source.genres.isNotEmpty) dest.genre = source.genres.first;

    // Copy album art - MP4 uses singular 'picture', take first from pictures list
    if (source.pictures.isNotEmpty) {
      dest.picture = source.pictures.first;
      print('[MetadataService] Copied album art to MP4');
    } else {
      print('[MetadataService] No album art to copy to MP4');
    }
  }

  /// Copy AudioMetadata to VorbisMetadata (FLAC, OGG, OPUS)
  static void _copyToVorbis(AudioMetadata source, VorbisMetadata dest) {
    // Copy basic metadata using AudioMetadata properties
    if (source.title != null) dest.title = [source.title!];
    if (source.artist != null) dest.artist = [source.artist!];
    if (source.album != null) dest.album = [source.album!];
    if (source.year != null) dest.date = [source.year!];
    if (source.trackNumber != null) dest.trackNumber = [source.trackNumber!];
    if (source.genres.isNotEmpty) dest.genres = source.genres;

    // Copy album art from universal pictures property
    if (source.pictures.isNotEmpty) {
      dest.pictures = source.pictures;
      print('[MetadataService] Copied ${source.pictures.length} album art(s) to Vorbis');
    } else {
      print('[MetadataService] No album art to copy to Vorbis');
    }
  }

  /// Copy AudioMetadata to RiffMetadata (WAV)
  static void _copyToRiff(AudioMetadata source, RiffMetadata dest) {
    // Copy basic metadata using AudioMetadata properties
    if (source.title != null) dest.title = source.title;
    if (source.artist != null) dest.artist = source.artist;
    if (source.album != null) dest.album = source.album;
    if (source.year != null) dest.year = source.year;
    if (source.trackNumber != null) dest.trackNumber = source.trackNumber;
    if (source.genres.isNotEmpty) dest.genre = source.genres.first;

    // Copy album art from universal pictures property
    if (source.pictures.isNotEmpty) {
      dest.pictures = source.pictures;
      print('[MetadataService] Copied ${source.pictures.length} album art(s) to RIFF/WAV');
    } else {
      print('[MetadataService] No album art to copy to RIFF/WAV');
    }
  }
}
