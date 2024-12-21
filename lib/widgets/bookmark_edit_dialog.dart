import 'package:flutter/material.dart';
import '../models/bookmark.dart';
import '../models/category.dart' as cat;

class BookmarkEditDialog extends StatefulWidget {
  final Bookmark bookmark;
  final List<cat.Category> categories;

  const BookmarkEditDialog(
      {super.key, required this.bookmark, required this.categories});

  @override
  _BookmarkEditDialogState createState() => _BookmarkEditDialogState();
}

class _BookmarkEditDialogState extends State<BookmarkEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _urlController;
  cat.Category? _selectedCategory;
  List<cat.Category> _categories = [];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.bookmark.title);
    _urlController = TextEditingController(text: widget.bookmark.url);
    _categories = widget.categories;
    _selectedCategory = widget.bookmark.categoryId != null
        ? _categories.firstWhere(
            (category) => category.id == widget.bookmark.categoryId,
            orElse: () => cat.Category(id: -1, name: 'No Category'),
          )
        : null;
  }

  @override
  void didUpdateWidget(covariant BookmarkEditDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.categories != oldWidget.categories) {
      setState(() {
        _categories = widget.categories;
        if (_selectedCategory != null) {
          final newSelectedCategory = _categories.firstWhere(
            (category) => category.id == _selectedCategory!.id,
            orElse: () => cat.Category(id: -1, name: 'No Category'),
          );
          _selectedCategory =
              newSelectedCategory.id == -1 ? null : newSelectedCategory;
        }
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('북마크 편집'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: '제목'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '제목을 입력해주세요';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _urlController,
                decoration: const InputDecoration(labelText: 'URL'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'URL을 입력해주세요';
                  }
                  return null;
                },
              ),
              DropdownButtonFormField<cat.Category>(
                value: _selectedCategory,
                hint: const Text('카테고리 선택'),
                items: _categories.map((category) {
                  return DropdownMenuItem<cat.Category>(
                    value: category,
                    child: Text(category.name),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value;
                  });
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
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final updatedBookmark = Bookmark(
                id: widget.bookmark.id,
                title: _titleController.text,
                url: _urlController.text,
                thumbnail: widget.bookmark.thumbnail,
                description: _titleController.text,
                createdAt: widget.bookmark.createdAt,
                categoryId:
                    _selectedCategory?.id == -1 ? null : _selectedCategory?.id,
              );
              Navigator.pop(context, updatedBookmark);
            }
          },
          child: const Text('저장'),
        ),
      ],
    );
  }
}
