import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class TrainTimerDatabase {
  TrainTimerDatabase._(this._db);

  final QueryExecutor _db;

  static Future<TrainTimerDatabase> open() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = path.join(dir.path, 'train_timer.sqlite');
    final db = NativeDatabase.createInBackground(File(file));
    final database = TrainTimerDatabase._(db);
    await database._migrate();
    return database;
  }

  Future<void> _migrate() async {
    await _db.runCustom('''
CREATE TABLE IF NOT EXISTS profiles (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  station TEXT NOT NULL,
  line TEXT NOT NULL,
  direction TEXT NOT NULL,
  timetable_asset TEXT NOT NULL,
  sort_order INTEGER NOT NULL
)
''');
  }

  Future<void> close() => _db.close();
}
