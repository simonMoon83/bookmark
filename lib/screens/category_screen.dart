import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/category.dart' as cat;
import '../models/bookmark.dart';

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key});

  @override
  _CategoryScreenState createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
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
        title: const Text('카테고리 관리'),
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
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
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
              ),
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
