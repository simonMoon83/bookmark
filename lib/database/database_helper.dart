import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDB('bookmarks.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE bookmarks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        url TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        thumbnail TEXT,
        createdAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      // 테이블 삭제 후 재생성
      await db.execute('DROP TABLE IF EXISTS bookmarks');
      await _createDB(db, newVersion);
    }
  }

  Future<int> insertBookmark(Map<String, dynamic> bookmark) async {
    final db = await database;
    final id = await db.insert('bookmarks', bookmark);
    return id;
  }

  Future<List<Map<String, dynamic>>> getAllBookmarks() async {
    final db = await database;
    final result = await db.query('bookmarks', orderBy: 'createdAt DESC');
    return result;
  }

  Future<int> clearAllBookmarks() async {
    final db = await database;
    return await db.delete('bookmarks');
  }

  Future<int> deleteBookmark(int id) async {
    final db = await database;
    return await db.delete('bookmarks', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateBookmark(Map<String, dynamic> bookmark) async {
    final db = await database;
    return db.update(
      'bookmarks',
      bookmark,
      where: 'id = ?',
      whereArgs: [bookmark['id']],
    );
  }
}
