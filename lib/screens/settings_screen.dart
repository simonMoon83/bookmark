import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/category.dart' as cat;
import '../models/bookmark.dart';
import 'home_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final dbHelper = DatabaseHelper.instance;
  List<cat.Category> categories = [];

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
            ListTile(
              title: const Text('카테고리 관리'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                _showCategoryDialog(context, null);
              },
            ),
            Expanded(
              child: ReorderableListView(
                onReorder: (oldIndex, newIndex) async {
                  if (newIndex > oldIndex) {
                    newIndex -= 1;
                  }
                  final cat.Category item = categories.removeAt(oldIndex);
                  categories.insert(newIndex, item);
                  for (int i = 0; i < categories.length; i++) {
                    final updatedCategory = cat.Category(
                      id: categories[i].id,
                      name: categories[i].name,
                      order: i,
                    );
                    await dbHelper.updateCategory(updatedCategory);
                  }
                  setState(() {});
                },
                children: categories.map((category) {
                  return ListTile(
                    key: Key(category.id.toString()),
                    title: Text(category.name),
                    onTap: () {
                      _showCategoryDialog(context, category);
                    },
                    trailing: const Icon(Icons.drag_handle),
                  );
                }).toList(),
              ),
            ),
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children: [
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
                  child: const Text('카테고리 초기화'),
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
                  child: const Text('북마크 초기화'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('북마크 & 카테고리 초기화'),
                        content: const Text('모든 북마크와 카테고리가 삭제됩니다. 계속하시겠습니까?'),
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
                        const SnackBar(content: Text('모든 북마크와 카테고리가 삭제되었습니다')),
                      );
                      Navigator.pop(context, true);
                    }
                  },
                  child: const Text('초기화'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCategoryDialog(
      BuildContext context, cat.Category? category) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return CategoryDialog(category: category);
      },
    );
    if (result == true) {
      _loadCategories();
    }
  }
}

class CategoryDialog extends StatefulWidget {
  final cat.Category? category;
  const CategoryDialog({super.key, this.category});

  @override
  _CategoryDialogState createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<CategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _categoryNameController = TextEditingController();
  final dbHelper = DatabaseHelper.instance;
  List<cat.Category> categories = [];
  cat.Category? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    if (widget.category != null) {
      _selectedCategory = widget.category;
      _categoryNameController.text = widget.category!.name;
    }
  }

  Future<void> _loadCategories() async {
    final loadedCategories = await dbHelper.getAllCategories();
    setState(() {
      categories = loadedCategories;
    });
  }

  @override
  void dispose() {
    _categoryNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('카테고리 관리'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _categoryNameController,
                decoration: const InputDecoration(labelText: '카테고리 이름'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '카테고리 이름을 입력해주세요';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              if (_selectedCategory == null) {
                final newCategory = cat.Category(
                    name: _categoryNameController.text,
                    order: categories.length);
                await dbHelper.insertCategory(newCategory);
                if (!mounted) return;
                Navigator.pop(context, true);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('카테고리가 추가되었습니다')),
                );
              } else {
                final updatedCategory = cat.Category(
                  id: _selectedCategory!.id,
                  name: _categoryNameController.text,
                  order: _selectedCategory!.order,
                );
                await dbHelper.updateCategory(updatedCategory);
                if (!mounted) return;
                Navigator.pop(context, true);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('카테고리가 수정되었습니다')),
                );
              }
            }
          },
          child: const Text('저장'),
        ),
        if (_selectedCategory != null)
          TextButton(
            onPressed: () async {
              await dbHelper.deleteCategory(_selectedCategory!.id!);
              if (!mounted) return;
              Navigator.pop(context, true);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('카테고리가 삭제되었습니다')),
              );
            },
            child: const Text('삭제'),
          ),
      ],
    );
  }
}
