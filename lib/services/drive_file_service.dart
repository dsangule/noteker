import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:googleapis/drive/v3.dart' as drive;

import 'drive_auth_service.dart';

/// Handles Google Drive file operations
class DriveFileService {
  DriveFileService(this._authService);
  
  final DriveAuthService _authService;

  bool get isSignedIn => _authService.isSignedIn;
  drive.DriveApi? get _driveApi => _authService.driveApi;

  Future<String> ensureFolder(String folderName) async {
    if (_driveApi == null) {
      throw Exception('Not signed in to Drive');
    }

    // Search for existing folder
    final query = "name='$folderName' and mimeType='application/vnd.google-apps.folder' and trashed=false";
    final searchResult = await _driveApi!.files.list(q: query);

    if (searchResult.files != null && searchResult.files!.isNotEmpty) {
      final folderId = searchResult.files!.first.id!;
      debugPrint('[DriveFileService] Found existing folder: $folderId');
      return folderId;
    }

    // Create new folder
    final folder = drive.File()
      ..name = folderName
      ..mimeType = 'application/vnd.google-apps.folder';

    final created = await _driveApi!.files.create(folder);
    final folderId = created.id!;
    debugPrint('[DriveFileService] Created new folder: $folderId');
    return folderId;
  }

  Future<List<drive.File>> listMarkdownFiles(String folderId) async {
    if (_driveApi == null) {
      throw Exception('Not signed in to Drive');
    }

    final query = "'$folderId' in parents and name contains '.md' and trashed=false";
    final result = await _driveApi!.files.list(
      q: query,
      orderBy: 'modifiedTime desc',
    );

    return result.files ?? [];
  }

  Future<drive.File> createMarkdownFile(String folderId, String title, String content) async {
    if (_driveApi == null) {
      throw Exception('Not signed in to Drive');
    }

    final fileName = '$title.md';
    final file = drive.File()
      ..name = fileName
      ..parents = [folderId];

    final media = drive.Media(
      Stream.fromIterable([utf8.encode(content)]),
      content.length,
      contentType: 'text/markdown',
    );

    final created = await _driveApi!.files.create(file, uploadMedia: media);
    debugPrint('[DriveFileService] Created file: ${created.id}');
    return created;
  }

  Future<drive.File> updateMarkdownFile(String fileId, String title, String content) async {
    if (_driveApi == null) {
      throw Exception('Not signed in to Drive');
    }

    final fileName = '$title.md';
    final file = drive.File()..name = fileName;

    final media = drive.Media(
      Stream.fromIterable([utf8.encode(content)]),
      content.length,
      contentType: 'text/markdown',
    );

    final updated = await _driveApi!.files.update(file, fileId, uploadMedia: media);
    debugPrint('[DriveFileService] Updated file: ${updated.id}');
    return updated;
  }

  Future<String> downloadFileContent(String fileId) async {
    if (_driveApi == null) {
      throw Exception('Not signed in to Drive');
    }

    final response = await _driveApi!.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final bytes = <int>[];
    await for (final chunk in response.stream) {
      bytes.addAll(chunk);
    }

    return utf8.decode(bytes);
  }

  Future<void> deleteFile(String fileId) async {
    if (_driveApi == null) {
      throw Exception('Not signed in to Drive');
    }

    await _driveApi!.files.delete(fileId);
    debugPrint('[DriveFileService] Deleted file: $fileId');
  }
}
