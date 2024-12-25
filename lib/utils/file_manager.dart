import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../database/database_helper.dart';
import '../models/bookmark.dart';
import '../models/category.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

class FileManager {
  final dbHelper = DatabaseHelper.instance;

  Future<String?> exportData() async {
    final bookmarks = await dbHelper.getAllBookmarks();
    final categories = await dbHelper.getAllCategories();

    final data = {
      'bookmarks': bookmarks.map((bookmark) => bookmark.toMap()).toList(),
      'categories': categories.map((category) => category.toMap()).toList(),
    };

    final jsonString = jsonEncode(data);

    String? outputDirectory;
    outputDirectory = await FilePicker.platform.getDirectoryPath(
      initialDirectory: (await getDownloadsDirectory())?.path,
    );

    String outputFile;
    if (outputDirectory != null) {
      outputFile = p.join(outputDirectory, 'bookmark_data.json');
    } else {
      final directory = await getApplicationDocumentsDirectory();
      outputFile = p.join(directory.path, 'bookmark_data.json');
    }

    final file = File(outputFile);
    await file.writeAsString(jsonString);
    return file.path;
  }

  Future<void> importData(String filePath) async {
    final file = File(filePath);
    final jsonString = await file.readAsString();
    final data = jsonDecode(jsonString);

    if (data['bookmarks'] != null) {
      final List<dynamic> bookmarks = data['bookmarks'];
      for (final bookmarkData in bookmarks) {
        final bookmark = Bookmark.fromMap(bookmarkData);
        await dbHelper.insertBookmark(bookmark);
      }
    }

    if (data['categories'] != null) {
      final List<dynamic> categories = data['categories'];
      for (final categoryData in categories) {
        final category = Category.fromMap(categoryData);
        await dbHelper.insertCategory(category);
      }
    }
  }
}
