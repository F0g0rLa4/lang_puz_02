import 'dart:io';
import 'dart:async';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// --- DATA STRUCTURES & DATABASE HELPER ---
class VerbForm {
  final String form;
  final String label;
  const VerbForm(this.form, this.label);
}

enum CellType { colCell, rowCell, overlapCell } 
enum TypeDirection { neutral, across, down }

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  
  DatabaseHelper._init(); 

  Future<Database> get database async {
      if (_database != null) return _database!;

      String path = await getDatabasesPath();
      String fullPath = '$path/verball.db';

      if (!await File(fullPath).exists()) {
        throw FileSystemException(
          "CRITICAL: Database file 'verball.db' not found at $fullPath. "
          "Please check your installation path and configuration settings."
        );
      }

      _database = await openDatabase(fullPath);
      return _database!;
  }

  Future<T> _executeSafeQuery<T>(Future<T> Function(Database db) action) async {
    final db = await instance.database;
    return await action(db);
  }

  Future<List<VerbForm>> getAllFazerForms() async {
    return await _executeSafeQuery((db) async {
      final List<Map<String, dynamic>> maps = await db.query('verb_forms', where: 'verb_id = ?', whereArgs: [1]);
      return List.generate(maps.length, (i) => VerbForm(
        maps[i]['form_text'] as String,
        maps[i]['label_short'] as String,
      ));
    });
  }
}
