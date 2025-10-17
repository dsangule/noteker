import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Simple Google Drive helper service.
// Notes:
// - This uses package:google_sign_in for OAuth sign-in and package:googleapis for Drive API calls.
// - On mobile platforms configure OAuth consent and reversed client IDs per the package docs.
// - This service intentionally keeps logic small and synchronous-friendly; production apps
//   should add error handling, retries, and background sync.

class DriveService {
  GoogleSignIn? _googleSignIn;

  GoogleSignInAccount? _currentUser;
  drive.DriveApi? _driveApi;
  static const _kWebClientIdKey = 'drive_web_client_id';
  // Fallback when shared_preferences plugin is unavailable (e.g. plugin not registered yet).
  String? _inMemoryWebClientId;

  Future<GoogleSignInAccount?> signIn() async {
    // Check for unsupported platforms
    if (!kIsWeb && Platform.isMacOS) {
      debugPrint('[DriveService] Google Sign-In not supported on macOS desktop');
      throw UnsupportedError('Google Drive sync is not supported on macOS. Please use iOS, Android, or Web.');
    }
    
    // debug log
    debugPrint('[DriveService] initiating google sign-in');
    // On web, prefer silent sign-in first to avoid popup deprecation issues
    if (kIsWeb && _googleSignIn != null) {
      try {
        final silent = await _googleSignIn!.signInSilently();
        if (silent != null) {
          _currentUser = silent;
          debugPrint('[DriveService] signInSilently succeeded');
          final authHeaders = await _currentUser!.authHeaders;
          final client = GoogleHttpClient(authHeaders);
          _driveApi = drive.DriveApi(client);
          return _currentUser;
        }
      } on Exception catch (e) {
        debugPrint('[DriveService] signInSilently failed: $e');
        // fall through to interactive sign-in
      }
    }
    // Lazily create GoogleSignIn if needed (allows web clientId injection)
    if (_googleSignIn == null) {
      String? webClientId;
      try {
        final prefs = await SharedPreferences.getInstance();
        webClientId = prefs.getString(_kWebClientIdKey);
      } on MissingPluginException catch (e) {
        // Plugin not registered (common during quick hot-reloads or early dev); fall back to in-memory value.
        debugPrint(
          '[DriveService] SharedPreferences not available: $e; using in-memory client id',
        );
        webClientId = _inMemoryWebClientId;
      }

      _googleSignIn = GoogleSignIn(
        clientId: webClientId,
        // Use least-privilege scope that only allows files created/opened by the app
        scopes: [drive.DriveApi.driveFileScope],
      );
    }

    try {
      _currentUser = await _googleSignIn!.signIn();
      debugPrint('[DriveService] google sign-in returned: $_currentUser');
      if (_currentUser == null) {
        return null;
      }

      final authHeaders = await _currentUser!.authHeaders;
      debugPrint(
        '[DriveService] auth headers keys: ${authHeaders.keys.toList()}',
      );
      final client = GoogleHttpClient(authHeaders);
      _driveApi = drive.DriveApi(client);
      return _currentUser;
    } on Exception catch (e) {
      debugPrint('[DriveService] signIn failed: $e');
      return null;
    }
  }

  Future<GoogleSignInAccount?> signInSilently() async {
    // Check for unsupported platforms
    if (!kIsWeb && Platform.isMacOS) {
      debugPrint('[DriveService] Silent sign-in not supported on macOS desktop');
      return null;
    }
    
    // Ensure GoogleSignIn instance exists with stored web client id if any
    if (_googleSignIn == null) {
      String? webClientId;
      try {
        final prefs = await SharedPreferences.getInstance();
        webClientId = prefs.getString(_kWebClientIdKey);
      } on MissingPluginException catch (e) {
        debugPrint('[DriveService] SharedPreferences not available: $e; using in-memory client id');
        webClientId = _inMemoryWebClientId;
      }
      _googleSignIn = GoogleSignIn(
        clientId: webClientId,
        scopes: [drive.DriveApi.driveScope],
      );
    }
    try {
      final account = await _googleSignIn!.signInSilently();
      if (account == null) {
        return null;
      }
      _currentUser = account;
      final authHeaders = await _currentUser!.authHeaders;
      final client = GoogleHttpClient(authHeaders);
      _driveApi = drive.DriveApi(client);
      debugPrint('[DriveService] silent sign-in successful');
      return _currentUser;
    } on Exception catch (e) {
      debugPrint('[DriveService] silent sign-in failed: $e');
      return null;
    }
  }

  /// Small retry helper with exponential backoff for transient errors.
  Future<T> _withRetry<T>(
    Future<T> Function() fn, {
    int retries = 3,
    Duration initialDelay = const Duration(milliseconds: 300),
  }) async {
    var attempt = 0;
    var delay = initialDelay;
    while (true) {
      try {
        return await fn();
      } catch (e) {
        attempt++;
        if (attempt > retries) {
          rethrow;
        }
        debugPrint('[DriveService] transient error, retrying #$attempt after $delay: $e');
        await Future<void>.delayed(delay);
        delay *= 2;
      }
    }
  }

  /// Save a web OAuth client id to be used by `GoogleSignIn` on web.
  Future<void> setWebClientId(String clientId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kWebClientIdKey, clientId);
    } on MissingPluginException catch (e) {
      debugPrint(
        '[DriveService] Could not persist web client id (MissingPlugin): $e - saving in memory only',
      );
      _inMemoryWebClientId = clientId;
    }
    // Recreate _googleSignIn with the new client id
    _googleSignIn = GoogleSignIn(
      clientId: clientId,
      scopes: [drive.DriveApi.driveFileScope],
    );
  }

  Future<String?> getWebClientId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_kWebClientIdKey) ?? _inMemoryWebClientId;
    } on MissingPluginException catch (_) {
      debugPrint(
        '[DriveService] SharedPreferences not available when reading web client id; using in-memory value',
      );
      return _inMemoryWebClientId;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn?.signOut();
    _currentUser = null;
    _driveApi = null;
  }

  bool get isSignedIn => _currentUser != null && _driveApi != null;

  // List folders in the user's Drive root
  Future<List<drive.File>> listFolders() async {
    if (!isSignedIn) {
      throw StateError('Not signed in');
    }
    const q = "mimeType = 'application/vnd.google-apps.folder' and 'root' in parents and trashed = false";
    final list = await _withRetry(() async =>
        _driveApi!.files.list(q: q, orderBy: 'name', $fields: 'files(id,name,modifiedTime)'));
    return list.files ?? [];
  }

  // Ensure a folder with the given name exists in the user's Drive root. Returns folder id.
  Future<String> ensureFolder(String folderName) async {
    if (!isSignedIn) {
      throw StateError('Not signed in');
    }

    // Search for an existing folder by name in the root
    final q =
        "mimeType = 'application/vnd.google-apps.folder' and name = '$folderName' and 'root' in parents and trashed = false";
    final list = await _withRetry(() async =>
        _driveApi!.files.list(q: q, $fields: 'files(id,name)'));
    if (list.files != null && list.files!.isNotEmpty) {
      return list.files!.first.id!;
    }

    // Create the folder
    final folder = drive.File()
      ..name = folderName
      ..mimeType = 'application/vnd.google-apps.folder'
      ..parents = ['root'];
    final created = await _withRetry(() async =>
        _driveApi!.files.create(folder, $fields: 'id'));
    return created.id!;
  }

  // List markdown files (.md) inside a folder
  Future<List<drive.File>> listMarkdownFiles(String folderId) async {
    if (!isSignedIn) {
      throw StateError('Not signed in');
    }
    final q =
        "mimeType != 'application/vnd.google-apps.folder' and name contains '.md' and '$folderId' in parents and trashed = false";
    final list = await _withRetry(() async =>
        _driveApi!.files.list(q: q, $fields: 'files(id,name,mimeType,modifiedTime)'));
    return list.files ?? [];
  }

  // Download file content as string
  Future<String> downloadFileContent(String fileId) async {
    if (!isSignedIn) {
      throw StateError('Not signed in');
    }
    final result = await _driveApi!.files.get(fileId, downloadOptions: drive.DownloadOptions.fullMedia);
    final media = result as drive.Media;
    final bytes = <int>[];
    await for (final chunk in media.stream) {
      bytes.addAll(chunk);
    }
    return utf8.decode(bytes);
  }

  // Create a new markdown file in the specified folder and return the created file metadata.
  Future<drive.File> createMarkdownFile(
    String folderId,
    String name,
    String content,
  ) async {
    if (!isSignedIn) {
      throw StateError('Not signed in');
    }
    final media = drive.Media(
      Stream.value(utf8.encode(content)),
      content.length,
      contentType: 'text/markdown',
    );
    final file = drive.File()
      ..name = name.endsWith('.md') ? name : '$name.md'
      ..parents = [folderId]
      ..mimeType = 'text/markdown';
    final created = await _withRetry(() async => _driveApi!.files.create(
          file,
          uploadMedia: media,
          $fields: 'id,name,modifiedTime',
        ));
    return created;
  }

  // Update an existing markdown file by fileId
  Future<drive.File> updateMarkdownFile(
    String fileId,
    String name,
    String content,
  ) async {
    if (!isSignedIn) {
      throw StateError('Not signed in');
    }
    final media = drive.Media(
      Stream.value(utf8.encode(content)),
      content.length,
      contentType: 'text/markdown',
    );
    final file = drive.File()..name = name.endsWith('.md') ? name : '$name.md';
    final updated = await _withRetry(() async => _driveApi!.files.update(
          file,
          fileId,
          uploadMedia: media,
          $fields: 'id,name,modifiedTime',
        ));
    return updated;
  }

  // Delete a file on Drive by id
  Future<void> deleteFile(String fileId) async {
    if (!isSignedIn) {
      throw StateError('Not signed in');
    }
    await _withRetry(() async => _driveApi!.files.delete(fileId));
  }
}

// A small HTTP client that injects Google auth headers into requests used by googleapis.
class GoogleHttpClient extends http.BaseClient {
  GoogleHttpClient(this._headers, [http.Client? inner])
      : _inner = inner ?? http.Client();

  final Map<String, String> _headers;
  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
