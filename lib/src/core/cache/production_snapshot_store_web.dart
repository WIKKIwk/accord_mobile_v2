import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'production_snapshot_store_backend.dart';

ProductionSnapshotBackend createProductionSnapshotBackend() =>
    WebProductionSnapshotBackend();

/// IndexedDB-backed SQLite, matching the application's existing chat runtime.
/// Using its factory directly does not change the global chat database factory.
class WebProductionSnapshotBackend implements ProductionSnapshotBackend {
  Future<Database>? _opening;

  Future<Database> _database() {
    return _opening ??= databaseFactoryFfiWeb
        .openDatabase(
      'accord_production_snapshots_v1.db',
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) => db.execute('''
          CREATE TABLE production_snapshots (
            id TEXT PRIMARY KEY,
            saved_at_ms INTEGER NOT NULL,
            value BLOB NOT NULL
          )
        '''),
      ),
    )
        .catchError((Object error) {
      _opening = null;
      throw error;
    });
  }

  @override
  Future<Uint8List?> read(String id, {required int maxBytes}) async {
    final rows = await (await _database()).query(
      'production_snapshots',
      columns: ['value'],
      where: 'id = ? AND length(value) <= ?',
      whereArgs: [id, maxBytes],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final value = rows.single['value'];
    return value is Uint8List ? value : null;
  }

  @override
  Future<void> write(String id, Uint8List bytes,
      {required int savedAtMs}) async {
    await (await _database()).insert(
      'production_snapshots',
      {'id': id, 'saved_at_ms': savedAtMs, 'value': bytes},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<ProductionSnapshotStoredEntry>> entries() async {
    final rows = await (await _database())
        .rawQuery('SELECT id, saved_at_ms, length(value) AS bytes '
            'FROM production_snapshots');
    return [
      for (final row in rows)
        ProductionSnapshotStoredEntry(
          id: row['id'] as String,
          bytes: row['bytes'] as int,
          savedAtMs: row['saved_at_ms'] as int,
        ),
    ];
  }

  @override
  Future<void> remove(String id) async {
    await (await _database())
        .delete('production_snapshots', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> clear() async {
    await (await _database()).delete('production_snapshots');
  }
}
