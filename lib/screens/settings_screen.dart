import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/category.dart' as cat;
import '../models/bookmark.dart';
import 'home_screen.dart';
import '../utils/file_manager.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import 'category_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final dbHelper = DatabaseHelper.instance;
  List<cat.Category> categories = [];
  final _fileManager = FileManager();

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final loadedCategories = await dbHelper.getAllCategories();
    setState(() {
      categories = loadedCategories;
    });
  }

  void _showImportExportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Import / Export'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                onPressed: () async {
                  final path = await _fileManager.exportData();
                  if (!mounted) return;
                  if (path != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Data exported to: $path')),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Export cancelled')),
                    );
                  }
                  Navigator.pop(context);
                },
                child: const Text('Export'),
              ),
              ElevatedButton(
                onPressed: () async {
                  FilePickerResult? result =
                      await FilePicker.platform.pickFiles();

                  if (result != null && result.files.single.path != null) {
                    final filePath = result.files.single.path!;
                    await _fileManager.importData(filePath);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Data imported')),
                    );
                    Navigator.pop(context);
                  }
                },
                child: const Text('Import'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    ListTile(
                      title: const Text('화면 모드'),
                    ),
                    Consumer<ThemeNotifier>(
                      builder: (context, themeNotifier, child) {
                        return Column(
                          children: [
                            RadioListTile<ThemeMode>(
                              title: const Text('라이트 모드'),
                              value: ThemeMode.light,
                              groupValue: themeNotifier.themeMode,
                              onChanged: (value) =>
                                  themeNotifier.setThemeMode(value!),
                            ),
                            RadioListTile<ThemeMode>(
                              title: const Text('다크 모드'),
                              value: ThemeMode.dark,
                              groupValue: themeNotifier.themeMode,
                              onChanged: (value) =>
                                  themeNotifier.setThemeMode(value!),
                            ),
                            RadioListTile<ThemeMode>(
                              title: const Text('시스템 모드'),
                              value: ThemeMode.system,
                              groupValue: themeNotifier.themeMode,
                              onChanged: (value) =>
                                  themeNotifier.setThemeMode(value!),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Column(
              children: [
                Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                  alignment: WrapAlignment.spaceAround,
                  children: [
                    ElevatedButton(
                      onPressed: () => _showImportExportDialog(context),
                      style:
                          ElevatedButton.styleFrom(minimumSize: Size(150, 30)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.import_export_outlined),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Import / Export',
                              softWrap: true,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('카테고리 초기화'),
                            content: const Text('모든 카테고리가 삭제됩니다. 계속하시겠습니까?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('취소'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('확인'),
                              ),
                            ],
                          ),
                        );

                        if (confirmed == true) {
                          List<Bookmark> bookmarks =
                              await dbHelper.getAllBookmarks();
                          for (final category in categories) {
                            await dbHelper.deleteCategory(category.id!);
                            for (final bookmark in bookmarks) {
                              if (bookmark.categoryId == category.id) {
                                final updatedBookmark = Bookmark(
                                  id: bookmark.id,
                                  url: bookmark.url,
                                  title: bookmark.title,
                                  thumbnail: bookmark.thumbnail,
                                  description: bookmark.description,
                                  createdAt: bookmark.createdAt,
                                  categoryId: null,
                                );
                                await dbHelper.updateBookmark(updatedBookmark);
                              }
                            }
                          }
                          _loadCategories();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('모든 카테고리가 삭제되었습니다')),
                          );
                        }
                      },
                      style:
                          ElevatedButton.styleFrom(minimumSize: Size(150, 30)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.delete_forever_outlined),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '카테고리 초기화',
                              softWrap: true,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('북마크 초기화'),
                            content: const Text('모든 북마크가 삭제됩니다. 계속하시겠습니까?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('취소'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('확인'),
                              ),
                            ],
                          ),
                        );

                        if (confirmed == true) {
                          await dbHelper.clearAllBookmarks();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('모든 북마크가 삭제되었습니다')),
                          );
                          Navigator.pop(context, true);
                        }
                      },
                      style:
                          ElevatedButton.styleFrom(minimumSize: Size(150, 30)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.delete_forever_outlined),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '북마크 초기화',
                              softWrap: true,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('북마크 & 카테고리 초기화'),
                            content:
                                const Text('모든 북마크와 카테고리가 삭제됩니다. 계속하시겠습니까?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('취소'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('확인'),
                              ),
                            ],
                          ),
                        );

                        if (confirmed == true) {
                          List<Bookmark> bookmarks =
                              await dbHelper.getAllBookmarks();
                          for (final category in categories) {
                            await dbHelper.deleteCategory(category.id!);
                            for (final bookmark in bookmarks) {
                              if (bookmark.categoryId == category.id) {
                                final updatedBookmark = Bookmark(
                                  id: bookmark.id,
                                  url: bookmark.url,
                                  title: bookmark.title,
                                  thumbnail: bookmark.thumbnail,
                                  description: bookmark.description,
                                  createdAt: bookmark.createdAt,
                                  categoryId: null,
                                );
                                await dbHelper.updateBookmark(updatedBookmark);
                              }
                            }
                          }
                          await dbHelper.clearAllBookmarks();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('모든 북마크와 카테고리가 삭제되었습니다')),
                          );
                          Navigator.pop(context, true);
                        }
                      },
                      style:
                          ElevatedButton.styleFrom(minimumSize: Size(150, 30)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.delete_forever_outlined),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '초기화',
                              softWrap: true,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCategoryDialog(
      BuildContext context, cat.Category? category) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CategoryScreen(),
      ),
    );
  }
}
