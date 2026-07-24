import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lang_puz_02/utils/app_logger.dart';

// --- DATA STRUCTURES ---
class VerbForm {
  final String form;
  final String label;

  const VerbForm(this.form, this.label);
}

enum CellType { colCell, rowCell, overlapCell }

enum TypeDirection { neutral, across, down }

// --- DATABASE HELPER ---
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();

  DatabaseHelper._internal();

  static const String _dbName = 'verball.db';
  static const int _dbVersion = 1;

  Database? _database;
  String? _dbPath;

  Future<Database> initialize() async {
    if (_database != null) {
      return _database!;
    }

    try {
      AppLogger.info('Initializing database...');

      final databasesPath = await getDatabasesPath();
      final dbPath = p.join(databasesPath, _dbName);
      _dbPath = dbPath;

      // final dbExists = await databaseExists(dbPath);

      if (!await databaseExists(dbPath)) {
        AppLogger.info('Database not found. Copying from assets...');
        await _copyDatabaseFromAsset(dbPath);
      } else {
        AppLogger.info('Database already exists at $dbPath');
      }

      _database = await openDatabase(
        dbPath,
        version: _dbVersion,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onUpgrade: _onUpgrade,
      );
      return _database!;

    } catch (error, stackTrace) {
      AppLogger.error(
        'Database initialization failed', error, stackTrace);
      rethrow;
    }
  }

  Future<Database> get database async {
    return _database ?? await initialize();   // initialize if not already done
  }

  String? get databasePath => _dbPath;

  Future<void> _copyDatabaseFromAsset(String dbPath) async {
    try {
      await Directory(p.dirname(dbPath)).create(recursive: true);

      final data = await rootBundle.load(p.join('assets', _dbName));

      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );

      await File(dbPath).writeAsBytes(bytes, flush: true);

      AppLogger.info('Database copied successfully to $dbPath');
    } catch (error, stackTrace) {
      AppLogger.error('Could not copy database from assets', error, stackTrace);
      rethrow;
    }
  }

  Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    AppLogger.info('Upgrading database from $oldVersion to $newVersion');

    if (oldVersion < 2) {
      // await db.execute('ALTER TABLE ...');
    }

    if (oldVersion < 3) {
      // await db.execute('CREATE INDEX ...');
    }
  }

  Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      AppLogger.info('Database closed.');
    }
  }

  Future<T> _executeSafeQuery<T>(
    Future<T> Function(Database db) action,
  ) async {
    try {
      final db = await database;
      return await action(db);
    } catch (error, stackTrace) {
      AppLogger.error('Database query failed', error, stackTrace);
      rethrow;
    }
  }

  Future<List<VerbForm>> getAllFazerForms() async {
    return _executeSafeQuery((db) async {
      final maps = await db.query(
        'verb_forms',
        where: 'verb_id = ?',
        whereArgs: [1],
      );

      return List.generate(
        maps.length,
        (i) => VerbForm(
          maps[i]['form_text'] as String,
          maps[i]['label_short'] as String,
        ),
      );
    });
  }
}