import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Handles Google Drive authentication and client setup
class DriveAuthService {
  GoogleSignIn? _googleSignIn;
  GoogleSignInAccount? _currentUser;
  drive.DriveApi? _driveApi;
  
  static const _kWebClientIdKey = 'drive_web_client_id';
  // Fallback when shared_preferences plugin is unavailable
  String? _inMemoryWebClientId;

  bool get isSignedIn => _currentUser != null;
  GoogleSignInAccount? get currentUser => _currentUser;
  drive.DriveApi? get driveApi => _driveApi;

  Future<GoogleSignInAccount?> signIn() async {
    debugPrint('[DriveAuthService] initiating google sign-in');
    
    // On web, prefer silent sign-in first to avoid popup deprecation issues
    if (kIsWeb && _googleSignIn != null) {
      try {
        final silent = await _googleSignIn!.signInSilently();
        if (silent != null) {
          _currentUser = silent;
          debugPrint('[DriveAuthService] signInSilently succeeded');
          final authHeaders = await _currentUser!.authHeaders;
          final client = GoogleHttpClient(authHeaders);
          _driveApi = drive.DriveApi(client);
          return _currentUser;
        }
      } on Exception catch (e) {
        debugPrint('[DriveAuthService] signInSilently failed: $e');
        // fall through to interactive sign-in
      }
    }
    
    // Lazily create GoogleSignIn if needed (allows web clientId injection)
    if (_googleSignIn == null) {
      String? webClientId;
      try {
        webClientId = await getWebClientId();
      } on Exception {
        // Ignore; will use default scopes
      }
      
      _googleSignIn = GoogleSignIn(
        clientId: webClientId,
        scopes: [
          drive.DriveApi.driveFileScope,
        ],
      );
    }
    
    try {
      final account = await _googleSignIn!.signIn();
      if (account != null) {
        _currentUser = account;
        final authHeaders = await account.authHeaders;
        final client = GoogleHttpClient(authHeaders);
        _driveApi = drive.DriveApi(client);
        debugPrint('[DriveAuthService] interactive sign-in succeeded');
      }
      return account;
    } on Exception catch (e) {
      debugPrint('[DriveAuthService] interactive sign-in failed: $e');
      return null;
    }
  }

  Future<GoogleSignInAccount?> signInSilently() async {
    if (_googleSignIn == null) {
      // Initialize GoogleSignIn first
      await signIn();
      return _currentUser;
    }
    
    try {
      final account = await _googleSignIn!.signInSilently();
      if (account != null) {
        _currentUser = account;
        final authHeaders = await account.authHeaders;
        final client = GoogleHttpClient(authHeaders);
        _driveApi = drive.DriveApi(client);
      }
      return account;
    } on Exception catch (e) {
      debugPrint('[DriveAuthService] silent sign-in failed: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    if (_googleSignIn != null) {
      await _googleSignIn!.signOut();
    }
    _currentUser = null;
    _driveApi = null;
  }

  Future<String?> getWebClientId() async {
    if (_inMemoryWebClientId != null) {
      return _inMemoryWebClientId;
    }
    
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_kWebClientIdKey);
    } on Exception {
      return _inMemoryWebClientId;
    }
  }

  Future<void> setWebClientId(String clientId) async {
    _inMemoryWebClientId = clientId;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kWebClientIdKey, clientId);
    } on Exception {
      // Store in memory only if SharedPreferences fails
    }
  }
}

/// HTTP client that adds Google auth headers
class GoogleHttpClient extends http.BaseClient {
  GoogleHttpClient(this._headers);
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }

  @override
  void close() {
    _client.close();
  }
}
