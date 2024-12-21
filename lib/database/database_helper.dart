import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/bookmark.dart';
import '../models/category.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'bookmark.db');

    return await openDatabase(path,
        version: 2, onCreate: _onCreate, onUpgrade: _onUpgrade);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE categories ADD COLUMN `order` INTEGER');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE bookmarks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        url TEXT,
        title TEXT,
        thumbnail TEXT,
        description TEXT,
        createdAt TEXT,
        categoryId INTEGER,
        FOREIGN KEY (categoryId) REFERENCES categories(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        `order` INTEGER
      )
    ''');
  }

  Future<int> insertBookmark(Bookmark bookmark) async {
    final db = await database;
    return await db.insert('bookmarks', bookmark.toMap());
  }

  Future<int> updateBookmark(Bookmark bookmark) async {
    final db = await database;
    return await db.update('bookmarks', bookmark.toMap(),
        where: 'id = ?', whereArgs: [bookmark.id]);
  }

  Future<List<Bookmark>> getAllBookmarks() async {
    final db = await database;
    final List<Map<String, dynamic>> maps =
        await db.query('bookmarks', orderBy: 'createdAt DESC');
    return List.generate(maps.length, (i) => Bookmark.fromMap(maps[i]));
  }

  Future<void> clearAllBookmarks() async {
    final db = await database;
    await db.delete('bookmarks');
  }

  Future<int> deleteBookmark(int id) async {
    final db = await database;
    return await db.delete('bookmarks', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> insertCategory(Category category) async {
    final db = await database;
    return await db.insert('categories', category.toMap());
  }

  Future<int> updateCategory(Category category) async {
    final db = await database;
    return await db.update('categories', category.toMap(),
        where: 'id = ?', whereArgs: [category.id]);
  }

  Future<List<Category>> getAllCategories() async {
    final db = await database;
    final List<Map<String, dynamic>> maps =
        await db.query('categories', orderBy: '`order` ASC');
    return List.generate(maps.length, (i) => Category.fromMap(maps[i]));
  }

  Future<int> deleteCategory(int id) async {
    final db = await database;
    return await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }
}
