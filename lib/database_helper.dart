import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static Database? _database;

  static Future<Database> getDatabase() async {
    if (_database != null) return _database!;

    final path = join(await getDatabasesPath(), 'fittrackv2.db');
    _database = await openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE workouts(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, date TEXT, durationMinutes INTEGER, imagePath TEXT)',
        );
        await db.execute(
          'CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT)',
        );
        await db.execute(
          'CREATE TABLE daily_steps(date TEXT PRIMARY KEY, steps INTEGER)',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'CREATE TABLE IF NOT EXISTS daily_steps(date TEXT PRIMARY KEY, steps INTEGER)',
          );
        }
        if (oldVersion < 3) {
          await db.execute(
            'CREATE TABLE IF NOT EXISTS settings(key TEXT PRIMARY KEY, value TEXT)',
          );
          await db.execute(
            'CREATE TABLE IF NOT EXISTS workouts(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, date TEXT, durationMinutes INTEGER, imagePath TEXT)',
          );
        }
      },
    );

    return _database!;
  }

  static Future<List<Map<String, dynamic>>> getWorkouts() async {
    final db = await getDatabase();
    return db.query('workouts', orderBy: 'date DESC, id DESC');
  }

  static Future<void> insertWorkout(Map<String, dynamic> workout) async {
    final db = await getDatabase();
    await db.insert('workouts', workout);
  }

  static Future<String?> getSetting(String key) async {
    final db = await getDatabase();
    final rows = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  static Future<void> setSetting(String key, String value) async {
    final db = await getDatabase();
    await db.insert('settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> addDailySteps(String date, int delta) async {
    final db = await getDatabase();
    final count = await db.rawUpdate(
      'UPDATE daily_steps SET steps = steps + ? WHERE date = ?',
      [delta, date],
    );

    if (count == 0) {
      await db.insert('daily_steps', {'date': date, 'steps': delta});
    }
  }

  static Future<List<Map<String, dynamic>>> getDailySteps() async {
    final db = await getDatabase();
    return db.query('daily_steps', orderBy: 'date DESC');
  }

  static Future<int> getStepsForDate(String date) async {
    final db = await getDatabase();
    final rows = await db.query(
      'daily_steps',
      where: 'date = ?',
      whereArgs: [date],
    );
    if (rows.isEmpty) return 0;
    return rows.first['steps'] as int;
  }

  // Added last 7 days of steps, weekly workout count,
  // and weekly total workout in minutes
  static Future<List<int>> getLast7DaysSteps() async {
    final List<int> result = [];

    for (int i = 6; i >= 0; i--) {
      final date = DateTime.now().subtract(Duration(days: i));
      final dateStr = date.toIso8601String().split('T')[0];
      final steps = await getStepsForDate(dateStr);
      result.add(steps);
    }

    return result;
  }

  static Future<int> getWorkoutCountLast7Days() async {
    final db = await getDatabase();
    final startDate = DateTime.now()
        .subtract(const Duration(days: 6))
        .toIso8601String()
        .split('T')[0];

    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM workouts WHERE date >= ?',
      [startDate],
    );

    return (rows.first['count'] as int?) ?? 0;
  }

  static Future<int> getWorkoutMinutesLast7Days() async {
    final db = await getDatabase();
    final startDate = DateTime.now()
        .subtract(const Duration(days: 6))
        .toIso8601String()
        .split('T')[0];

    final rows = await db.rawQuery(
      'SELECT SUM(durationMinutes) AS total FROM workouts WHERE date >= ?',
      [startDate],
    );

    return (rows.first['total'] as int?) ?? 0;
  }
}
