// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class AppLogger {
  static File? _logFile;
  
  // The Catcher's Mitt: Looks for a variable passed via --dart-define from the compiler
  static const String _envCommit = String.fromEnvironment('GIT_COMMIT');

static Future<void> init() async {
    try {
      String logDirectoryPath;

      // If we are developing (Debug Mode) on a Desktop OS:
      if (kDebugMode && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
        logDirectoryPath = '${Directory.current.path}/logs';
        
        final logDir = Directory(logDirectoryPath);
        if (!logDir.existsSync()) {
          logDir.createSync(recursive: true);
        }
      } else {
        // Fallback for Mobile or Production Release Builds
        final directory = await getApplicationDocumentsDirectory();
        logDirectoryPath = directory.path;
      }

      final path = '$logDirectoryPath/verball_debug_log.txt';
      _logFile = File(path);

      String currentCommit = await _getCommitHash();

      print("📝 [AppLogger] Writing physical logs to: $path");
      
      info("=== App Started ===");
      info("=== Build Commit: $currentCommit ===");
      
    } catch (e) {
      print("Failed to initialize log file: $e");
    }
  }

  // 2. The Smart Hash Finder
  static Future<String> _getCommitHash() async {
    // A. Did we pass it via --dart-define during a release build? 
    if (_envCommit.isNotEmpty) {
      return _envCommit;
    }

    // B. Are we pressing F5 in Debug Mode on a Desktop OS? 
    if (kDebugMode && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      try {
        // Opens an invisible terminal, runs git, and captures the text output
        final result = await Process.run('git', ['rev-parse', '--short', 'HEAD']);
        
        if (result.exitCode == 0) {
          // .trim() removes the invisible 'enter' key at the end of the git output
          return "${result.stdout.toString().trim()} (F5 Debug)";
        }
      } catch (e) {
        // Git wasn't installed, or the folder isn't a git repo yet
        return "Local-Uncommitted (Git Error)";
      }
    }

    // C. The ultimate fallback for mobile emulators without --dart-define
    return "Local-Uncommitted";
  }

  // 3. The internal file writer with timestamps
  static void _writeToFile(String prefix, String message, [Object? error, StackTrace? stackTrace]) async {
    if (_logFile == null) return;

    // Generate a clean timestamp: "2026-06-20 17:10:09.123"
    final timestamp = DateTime.now().toString();
    
    final buffer = StringBuffer();
    buffer.writeln('[$timestamp] $prefix $message');
    
    if (error != null) buffer.writeln('Exception: $error');
    if (stackTrace != null) buffer.writeln('Stack: $stackTrace');

    try {
      // Append the new text to the bottom of the file
      await _logFile!.writeAsString(buffer.toString(), mode: FileMode.append);
    } catch (e) {
      developer.log('Failed to write to log file', error: e);
    }
  }

  // 4. Your Info log
  static void info(String message) {
    if (kDebugMode) {
      developer.log(message, name: 'Verball.Info');
      _writeToFile('[INFO]', message);
    }
  }

  // 5. Your Error log
  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      developer.log(message, name: 'Verball.Error', error: error, stackTrace: stackTrace, level: 1000);
      _writeToFile('[ERROR]', message, error, stackTrace);
    }
  }
}