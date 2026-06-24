import 'package:sqflite/sqflite.dart';

/// Extracts the metadata version injected by the database creator app.
Future<String> getBundledDbVersion(Database db) async {
  try {
    List<Map<String, dynamic>> result = await db.query(
      'db_metadata',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['version'],
    );

    if (result.isNotEmpty) {
      return result.first['value'] as String;
    }
    return 'db-version-missing';
  } catch (e) {
    // Fails safely if the table doesn't exist yet
    return 'db-uninitialized';
  }
}