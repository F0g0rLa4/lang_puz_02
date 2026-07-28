import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // for Keyboard Events & rootBundle
// import 'dart:async';  // for Timer
import 'dart:io';     // for File
import 'package:path/path.dart' as p;  
import 'package:sqflite_common_ffi/sqflite_ffi.dart'; // Desktop SQLite FFI
import 'package:lang_puz_02/utils/dbhelpers_models.dart';  // for DatabaseHelper and VerbForm
import 'package:lang_puz_02/utils/aa_logger_meta.dart';  // barrel for AppLogger and metadata
import 'package:lang_puz_02/pages/puzzle_choices_page.dart';
import 'package:lang_puz_02/pages/crossword.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  _configureDatabaseForPlatform();

  try {
  
    // Prepare metadata for logging and to pass to the UI
    final osInfo = getDetailedOS();
    final appName = await getAppName();
    final appVersion = await getAppSemanticVersion();
    final dbDummy = "initializing database...";  // Placeholder until we get the actual version
    String metadataCombined =
        'OS: $osInfo | '
        'App Version: $appVersion | '
        'Bundled DB Version: $dbDummy';
    await AppLogger.init(
      appName:  appName,
      metadataCombined: metadataCombined,     );
    AppLogger.info('AppLogger initializing. Preparing for db initialization');

    final Database db = await DatabaseHelper.instance.initialize();
    // Get the actual bundled database version after db initialization & add it to metadataCombined
    final dbVersion = await getBundledDbVersion(db);
    metadataCombined =
      'OS: $osInfo | '
      'App Version: $appVersion | '
      'Bundled DB Version: $dbVersion';
    await AppLogger.metaDbUpdate(
      metadataCombined: metadataCombined);
     AppLogger.info('Starting the app with metadata: $metadataCombined');
    await AppLogger.flush(); // Ensure all startup entries have reached the log file.

    runApp(LangPuzzles(metadataCombined: metadataCombined));
  } catch (error, stackTrace) {
    stderr.writeln('Application initialization failed: $error');
    stderr.writeln(stackTrace);
    rethrow;
  }
}

void _configureDatabaseForPlatform() {
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
}
//==========================================================================
class LangPuzzles extends StatelessWidget {
  final String metadataCombined;
  const LangPuzzles({super.key, required this.metadataCombined});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Language Puzzles',
      theme: ThemeData(primarySwatch: Colors.blue),
      // Set the starting page
      initialRoute: '/', 
      // Map string paths to your widgets
      routes: {
        '/': (context) => PuzzleChoicesPage(metadataCombined: metadataCombined),
        '/crossword': (context) => Crossword(metadataCombined: metadataCombined),
      },
    );
  }
}


