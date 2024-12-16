import 'package:flutter/material.dart';
import '../models/bookmark.dart';

class BookmarkEditDialog extends StatefulWidget {
  final Bookmark bookmark;

  const BookmarkEditDialog({super.key, required this.bookmark});

  @override
  State<BookmarkEditDialog> createState() => _BookmarkEditDialogState();
}

class _BookmarkEditDialogState extends State<BookmarkEditDialog> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.bookmark.title);
    _descriptionController =
        TextEditingController(text: widget.bookmark.description);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('북마크 편집'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.bookmark.thumbnail.isNotEmpty)
              Image.network(
                widget.bookmark.thumbnail,
                height: 150,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const Center(child: Icon(Icons.error)),
              ),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: '제목'),
            ),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: '설명'),
              maxLines: 3,
            ),
            const SizedBox(height: 8),
            Text(widget.bookmark.url,
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () {
            final editedBookmark = widget.bookmark.copyWith(
              title: _titleController.text,
              description: _descriptionController.text,
            );
            Navigator.pop(context, editedBookmark);
          },
          child: const Text('저장'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
