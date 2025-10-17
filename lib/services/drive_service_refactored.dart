import 'dart:async';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;

import 'drive_auth_service.dart';
import 'drive_file_service.dart';

/// Refactored DriveService that combines auth and file operations
/// This maintains the same interface as the original but uses composition
class DriveService {
  DriveService() {
    _authService = DriveAuthService();
    _fileService = DriveFileService(_authService);
  }

  late final DriveAuthService _authService;
  late final DriveFileService _fileService;

  // Authentication methods
  bool get isSignedIn => _authService.isSignedIn;
  GoogleSignInAccount? get currentUser => _authService.currentUser;

  Future<GoogleSignInAccount?> signIn() => _authService.signIn();
  Future<GoogleSignInAccount?> signInSilently() => _authService.signInSilently();
  Future<void> signOut() => _authService.signOut();
  Future<String?> getWebClientId() => _authService.getWebClientId();
  Future<void> setWebClientId(String clientId) => _authService.setWebClientId(clientId);

  // File operation methods
  Future<String> ensureFolder(String folderName) => _fileService.ensureFolder(folderName);
  Future<List<drive.File>> listMarkdownFiles(String folderId) => _fileService.listMarkdownFiles(folderId);
  Future<drive.File> createMarkdownFile(String folderId, String title, String content) => 
      _fileService.createMarkdownFile(folderId, title, content);
  Future<drive.File> updateMarkdownFile(String fileId, String title, String content) => 
      _fileService.updateMarkdownFile(fileId, title, content);
  Future<String> downloadFileContent(String fileId) => _fileService.downloadFileContent(fileId);
  Future<void> deleteFile(String fileId) => _fileService.deleteFile(fileId);
}
