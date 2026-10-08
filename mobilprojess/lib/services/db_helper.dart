import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../models/subscription_model.dart';
import '../models/user_model.dart';

class DbHelper {
  static final DbHelper _instance = DbHelper._internal();
  static Database? _database;

  static DbHelper get instance => _instance;

  factory DbHelper() => _instance;

  DbHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    String path = join(await getDatabasesPath(), 'subpulse.db');

    return await openDatabase(
      path,
      version: 4,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        email TEXT UNIQUE,
        password TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE subscriptions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId TEXT,
        name TEXT,
        price REAL,
        currency TEXT,
        category TEXT,
        billingDate TEXT,
        personCount INTEGER,
        packageName TEXT,
        isShared INTEGER,
        isTrial INTEGER DEFAULT 0,
        sharedMembersJson TEXT
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _safeAddColumn(
        db,
        'subscriptions',
        'isTrial',
        'INTEGER DEFAULT 0',
      );
    }

    if (oldVersion < 3) {
      await _migrateUserIdToText(db);
    }

    if (oldVersion < 4) {
      await _safeAddColumn(
        db,
        'subscriptions',
        'sharedMembersJson',
        'TEXT',
      );
    }
  }

  Future<void> _safeAddColumn(
      Database db,
      String table,
      String column,
      String type,
      ) async {
    try {
      await db.execute("ALTER TABLE $table ADD COLUMN $column $type");
    } catch (_) {}
  }

  Future<void> _migrateUserIdToText(Database db) async {
    await db.execute('''
      CREATE TABLE subscriptions_new (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId TEXT,
        name TEXT,
        price REAL,
        currency TEXT,
        category TEXT,
        billingDate TEXT,
        personCount INTEGER,
        packageName TEXT,
        isShared INTEGER,
        isTrial INTEGER DEFAULT 0,
        sharedMembersJson TEXT
      )
    ''');

    await db.execute('''
      INSERT INTO subscriptions_new (
        id,
        userId,
        name,
        price,
        currency,
        category,
        billingDate,
        personCount,
        packageName,
        isShared,
        isTrial
      )
      SELECT
        id,
        CAST(userId AS TEXT),
        name,
        price,
        currency,
        category,
        billingDate,
        personCount,
        packageName,
        isShared,
        isTrial
      FROM subscriptions
    ''');

    await db.execute('DROP TABLE subscriptions');
    await db.execute('ALTER TABLE subscriptions_new RENAME TO subscriptions');
  }

  Future<int> insertSubscription(Subscription sub) async {
    final db = await database;
    return await db.insert('subscriptions', sub.toMap());
  }

  Future<int> updateSubscription(Subscription subscription) async {
    final db = await database;

    return await db.update(
      'subscriptions',
      subscription.toMap(),
      where: 'id = ? AND userId = ?',
      whereArgs: [subscription.id, subscription.userId],
    );
  }

  Future<int> deleteSubscription(int id) async {
    final db = await database;

    return await db.delete(
      'subscriptions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteSubscriptionByUser(int id, String userId) async {
    final db = await database;

    return await db.delete(
      'subscriptions',
      where: 'id = ? AND userId = ?',
      whereArgs: [id, userId],
    );
  }

  Future<List<Subscription>> getAllSubscriptions() async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query('subscriptions');

    return List.generate(maps.length, (i) {
      return Subscription.fromMap(maps[i]);
    });
  }

  Future<List<Subscription>> getSubscriptionsByUser(String userId) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'subscriptions',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'billingDate ASC',
    );

    return List.generate(maps.length, (i) {
      return Subscription.fromMap(maps[i]);
    });
  }

  Future<int> deleteAllSubscriptions() async {
    final db = await database;
    return await db.delete('subscriptions');
  }

  Future<int> deleteSubscriptionsByUser(String userId) async {
    final db = await database;

    return await db.delete(
      'subscriptions',
      where: 'userId = ?',
      whereArgs: [userId],
    );
  }

  Future<int> insertUser(User user) async {
    final db = await database;
    return await db.insert('users', user.toMap());
  }

  Future<User?> loginUser(String email, String password) async {
    final db = await database;

    final List<Map<String, dynamic>> res = await db.query(
      'users',
      where: 'email = ? AND password = ?',
      whereArgs: [email, password],
    );

    if (res.isNotEmpty) {
      return User.fromMap(res.first);
    }

    return null;
  }
}