import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/journey.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static const _dbName = 'chargeshield.db';
  static const _dbVersion = 2;

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), _dbName);
    final db = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    // WAL mode: safer concurrent access from background isolate.
    // Wrapped in try-catch so a pragma failure never blocks startup.
    try {
      await db.execute('PRAGMA journal_mode=WAL');
    } catch (_) {}
    return db;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE journeys (
        id TEXT PRIMARY KEY,
        vehicle_registration TEXT NOT NULL,
        zone_id TEXT NOT NULL,
        zone_name TEXT NOT NULL,
        entry_time TEXT NOT NULL,
        entry_lat REAL NOT NULL,
        entry_lng REAL NOT NULL,
        exit_time TEXT,
        exit_lat REAL,
        exit_lng REAL,
        charge REAL NOT NULL,
        payment_status TEXT NOT NULL DEFAULT 'unpaid',
        route_points TEXT
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_journeys_entry_time ON journeys(entry_time);
    ''');

    await db.execute('''
      CREATE INDEX idx_journeys_vehicle ON journeys(vehicle_registration);
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE journeys ADD COLUMN route_points TEXT');
    }
  }

  // ---------------------------------------------------------------------------
  // CRUD
  // ---------------------------------------------------------------------------

  Future<void> insertJourney(Journey journey) async {
    final db = await database;
    await db.insert(
      'journeys',
      journey.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateJourney(Journey journey) async {
    final db = await database;
    await db.update(
      'journeys',
      journey.toMap(),
      where: 'id = ?',
      whereArgs: [journey.id],
    );
  }

  Future<List<Journey>> getJourneys({
    String? vehicleRegistration,
    int? limitDays,
    int limit = 100,
    int offset = 0,
  }) async {
    final db = await database;
    final List<String> conditions = [];
    final List<dynamic> args = [];

    if (vehicleRegistration != null) {
      conditions.add('vehicle_registration = ?');
      args.add(vehicleRegistration);
    }

    if (limitDays != null) {
      final cutoff = DateTime.now().subtract(Duration(days: limitDays));
      conditions.add('entry_time >= ?');
      args.add(cutoff.toIso8601String());
    }

    final where = conditions.isEmpty ? null : conditions.join(' AND ');
    args.addAll([limit, offset]);

    final maps = await db.query(
      'journeys',
      where: where,
      whereArgs: where != null ? args.sublist(0, args.length - 2) : null,
      orderBy: 'entry_time DESC',
      limit: limit,
      offset: offset,
    );

    return maps.map(Journey.fromMap).toList();
  }

  Future<Journey?> getJourneyById(String id) async {
    final db = await database;
    final maps = await db.query(
      'journeys',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Journey.fromMap(maps.first);
  }

  Future<void> updatePaymentStatus(String id, PaymentStatus status) async {
    final db = await database;
    await db.update(
      'journeys',
      {'payment_status': status.name},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteJourney(String id) async {
    final db = await database;
    await db.delete('journeys', where: 'id = ?', whereArgs: [id]);
  }

  /// Returns true if a journey already exists for [zoneId] + [vehicleRegistration]
  /// within today's calendar day (local time). Used to prevent duplicate charges
  /// for per-day zones (ULEZ, CCZ, LEZ, CAZ) when a vehicle re-enters the zone.
  Future<bool> hasTodayEntry(String zoneId, String vehicleRegistration) async {
    final db = await database;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    final result = await db.query(
      'journeys',
      where:
          'zone_id = ? AND vehicle_registration = ? AND entry_time >= ? AND entry_time < ?',
      whereArgs: [
        zoneId,
        vehicleRegistration,
        startOfDay.toIso8601String(),
        endOfDay.toIso8601String(),
      ],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<void> deleteJourneysOlderThan(int days) async {
    final db = await database;
    final cutoff = DateTime.now().subtract(Duration(days: days));
    await db.delete(
      'journeys',
      where: 'entry_time < ?',
      whereArgs: [cutoff.toIso8601String()],
    );
  }

  /// Total charges for a vehicle in a date range.
  /// Pass [onlyUnpaid] = true to sum only entries that haven't been paid yet.
  Future<double> totalCharges({
    String? vehicleRegistration,
    DateTime? from,
    DateTime? to,
    bool onlyUnpaid = false,
  }) async {
    final db = await database;
    final List<String> conditions = onlyUnpaid
        ? ["payment_status = 'unpaid'"]
        : ["payment_status != 'exempt'"];
    final List<dynamic> args = [];

    if (vehicleRegistration != null) {
      conditions.add('vehicle_registration = ?');
      args.add(vehicleRegistration);
    }
    if (from != null) {
      conditions.add('entry_time >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      conditions.add('entry_time <= ?');
      args.add(to.toIso8601String());
    }

    final result = await db.rawQuery(
      'SELECT SUM(charge) as total FROM journeys WHERE ${conditions.join(' AND ')}',
      args,
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }
}
