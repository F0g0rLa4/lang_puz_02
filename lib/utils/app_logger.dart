// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:async'; // to cue
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class AppLogger {
  static File? _logFile;
  
  // Store these at the class level so info() and error() can access them
  static String _appName = 'App';
  static String _sessionMetadata = 'No metadata provided';

  // The Catcher's Mitt: Looks for a variable passed via --dart-define from the compiler
  static const String _envCommit = String.fromEnvironment('GIT_COMMIT');

  /// Requires the appName and metadataCombined to be passed in from main.dart
  static Future<void> init({
    required String appName,
    required String metadataCombined,
  }) async {
    _appName = appName;
    _sessionMetadata = metadataCombined;

    try {
      String logDirectoryPath;

      if (
        kDebugMode &&
        (Platform.isWindows ||
            Platform.isMacOS ||
            Platform.isLinux)
      ) {
        logDirectoryPath =
            '${Directory.current.path}/logs';

        final logDir = Directory(logDirectoryPath);

        if (!await logDir.exists()) {
          await logDir.create(recursive: true);
        }
      } else {
        final directory =
            await getApplicationDocumentsDirectory();

        logDirectoryPath = directory.path;
      }

      final cleanAppName =
          appName.toLowerCase().replaceAll(' ', '_');

      final path =
          '$logDirectoryPath/${cleanAppName}_debug_log.txt';

      _logFile = File(path);

      final currentCommit = await _getCommitHash();

      await _writeToFile('[INFO]', 'Writing physical logs to: $path');
      await _writeToFile('[INFO]', '========================================');
      await _writeToFile('[INFO]', '=== $_appName Started ===');
      await _writeToFile('[INFO]', '=== Build Commit: $currentCommit ===' );
      await _writeToFile('[INFO]', '=== Session Metadata: $_sessionMetadata ===');
      await _writeToFile('[INFO]', '========================================');
      
    } catch (error, stackTrace) {
      developer.log(
        'Failed to initialize log file',
        name: 'AppLogger.Error',
        error: error,
        stackTrace: stackTrace,
        level: 1000,
      );

      stderr.writeln(
        'Failed to initialize log file: $error',
      );
      stderr.writeln(stackTrace);

      rethrow;
    }
}

  static Future<void> metaDbUpdate({
    required String metadataCombined,    
  })  async {
  _sessionMetadata = metadataCombined;

  await _writeToFile(
    '[INFO]', 'Session metadata updated: $_sessionMetadata',
  );
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

  // 3. The internal file writer with timestamps. Using a queue to ensure that writes are sequential and not overlapping
  static Future<void> _writeQueue = Future<void>.value();  // A completed future to start the queue. Each write will chain onto this future to ensure sequential writes.  

  static Future<void> _writeToFile(String prefix, String message, [Object? error, StackTrace? stackTrace])  {
      
    final logFile = _logFile;  // Copy pointer to local variable to avoid race conditions
    if (logFile == null) {
      return Future<void>.value();
    }
    // Generate a clean timestamp: "2026-06-20 17:10:09.123"
    final timestamp = DateTime.now().toString();
    
    final buffer = StringBuffer()
      ..writeln('[$timestamp] $prefix $message');
    if (error != null) buffer.writeln('Exception: $error');
    if (stackTrace != null) buffer.writeln('Stack: $stackTrace');
    final entry = buffer.toString();

  _writeQueue = _writeQueue.then((_) async {
    try {
      await logFile.writeAsString(
        entry,
        mode: FileMode.append,
        flush: true,
      );
    } catch (error, stackTrace) {   // If one write fails, we log to developer console and stderr, but we don't rethrow to allow next writes to continue
      developer.log(
        'Failed to write to log file',
        error: error,
        stackTrace: stackTrace,
      );
    }
  });

  return _writeQueue;
}

  // 4. Your Info log
  static void info(String message) {
  if (kDebugMode) {
    developer.log(                    // Developer log for debug console only
      message,
      name: '$_appName.Info',
    );
  }

  unawaited(
    _writeToFile('[INFO]', message),  // Physical file log in Debug & Release mode write to log, but don't block the main thread
  );
}

  // 5. Your Error log
  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    
      // Automatically append the session metadata to every error for easier debugging
      final contextMessage = '$message | Meta: $_sessionMetadata';
    if (kDebugMode) {
      developer.log(contextMessage, name: '$_appName.Error', error: error, stackTrace: stackTrace, level: 1000);
    }

    unawaited(
      _writeToFile( '[ERROR]', contextMessage, error, stackTrace)
    );

  }

  static Future<void> flush() async {
  await _writeQueue;
}
}