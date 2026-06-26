import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // for Keyboard Events & rootBundle
// import 'dart:async';  // for Timer
import 'dart:io';     // for File
import 'package:path/path.dart' as p;  
import 'package:sqflite_common_ffi/sqflite_ffi.dart'; // Desktop SQLite FFI
import 'package:lang_puz_02/utils/aa_logger_meta.dart';  // barrel for AppLogger and metadata
import 'package:lang_puz_02/pages/puzzle_choices_page.dart';
import 'package:lang_puz_02/pages/crossword.dart';
//import 'package:lang_puz_02/utils/dbhelper_datastructures.dart'; 


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi; 
  }

  String osInfo = getDetailedOS();
  String appName = await getAppName(); 
  String appVersion = await getAppSemanticVersion(); 

  String databasesPath = await getDatabasesPath();
  String dbPath = p.join(databasesPath, 'verball.db');

  bool dbExists = await databaseExists(dbPath);

  if (!dbExists) {
    print("Database not found. Copying from assets...");
    try {
      await Directory(p.dirname(dbPath)).create(recursive: true);
    } catch (_) {}

    ByteData data = await rootBundle.load(p.join('assets', 'verball.db'));
    List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    await File(dbPath).writeAsBytes(bytes, flush: true);
    print("Database copied successfully.");
  }

  Database db = await openDatabase(dbPath);
  String dbVersion = await getBundledDbVersion(db);

  String metadataCombined = 'OS: $osInfo | App Version: $appVersion | Bundled DB Version: $dbVersion';

  await AppLogger.init(
    appName: appName,
    metadataCombined: metadataCombined,
  );
  AppLogger.info('App initialization complete. Booting UI.');
 
  runApp(LangPuzzles(metadataCombined: metadataCombined));
}

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


