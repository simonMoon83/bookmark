import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/bookmark.dart';
import '../widgets/bookmark_edit_dialog.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:share_plus/share_plus.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:url_launcher/url_launcher.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final dbHelper = DatabaseHelper.instance;
  List<Bookmark> bookmarks = [];

  @override
  void initState() {
    super.initState();
    loadBookmarks();
  }

  Future<void> loadBookmarks() async {
    final loadedBookmarks = await dbHelper.getAllBookmarks();
    if (!mounted) return;
    setState(() {
      bookmarks = loadedBookmarks.map((map) => Bookmark.fromMap(map)).toList();
    });
  }

  Future<void> _addBookmark(String url) async {
    try {
      Map<String, String> metadata;
      if (url.contains('youtu.be') || url.contains('youtube.com')) {
        final yt = YoutubeExplode();
        try {
          final video = await yt.videos.get(url);
          metadata = {
            'title': video.title,
            'description': video.description,
            'thumbnail': video.thumbnails.highResUrl,
          };
          yt.close();
        } catch (e) {
          print('YouTube metadata error: $e');
          metadata = await _fetchMetadata(url);
        }
      } else {
        metadata = await _fetchMetadata(url);
      }

      final bookmark = {
        'url': url,
        'title': metadata['title'] ?? url,
        'description': metadata['description'] ?? '',
        'thumbnail': metadata['thumbnail'] ?? '',
      };

      await dbHelper.insertBookmark(bookmark);
      loadBookmarks();
    } catch (e) {
      print('Error adding bookmark: $e');
    }
  }

  Future<Map<String, String>> _fetchMetadata(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final document = parser.parse(response.body);
        final title = document.querySelector('title')?.text ?? 'No Title';
        final metaTags = document.getElementsByTagName('meta');
        String? description;
        String? thumbnail;

        for (final tag in metaTags) {
          final property = tag.attributes['property']?.toLowerCase() ?? '';
          final name = tag.attributes['name']?.toLowerCase() ?? '';
          final content = tag.attributes['content'] ?? '';

          if (property == 'og:description' || name == 'description') {
            description = content;
          } else if (property == 'og:image') {
            thumbnail = content;
          }
        }

        return {
          'title': title,
          'thumbnail': thumbnail ?? '',
          'description': description ?? '',
        };
      }
    } catch (e) {
      print('Error fetching metadata: $e');
    }
    return {};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('북마크'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: loadBookmarks,
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: bookmarks.length,
        itemBuilder: (context, index) {
          final bookmark = bookmarks[index];
          return Dismissible(
            key: Key(bookmark.id.toString()),
            background: Container(
              color: Colors.red,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            direction: DismissDirection.endToStart,
            onDismissed: (direction) async {
              await dbHelper.deleteBookmark(bookmark.id!);
              setState(() {
                bookmarks.removeAt(index);
              });
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('북마크가 삭제되었습니다')),
              );
            },
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: InkWell(
                onTap: () async {
                  try {
                    final url = Uri.parse(bookmark.url);
                    print('Attempting to open URL: ${bookmark.url}');
                    
                    if (bookmark.url.contains('youtu.be') || bookmark.url.contains('youtube.com')) {
                      print('Detected YouTube URL');
                      if (await canLaunchUrl(url)) {
                        print('Launching YouTube URL in app');
                        final result = await launchUrl(
                          url,
                          mode: LaunchMode.externalNonBrowserApplication,
                        );
                        print('Launch result: $result');
                      } else {
                        print('Cannot launch YouTube URL');
                        // YouTube 앱이 없는 경우 브라우저에서 열기
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url, mode: LaunchMode.externalApplication);
                        }
                      }
                    } else {
                      print('Detected regular URL');
                      if (await canLaunchUrl(url)) {
                        print('Launching URL in browser');
                        final result = await launchUrl(
                          url,
                          mode: LaunchMode.externalApplication,
                        );
                        print('Launch result: $result');
                      } else {
                        print('Cannot launch URL');
                      }
                    }
                  } catch (e) {
                    print('Error launching URL: $e');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('URL을 열 수 없습니다: $e')),
                      );
                    }
                  }
                },
                child: ListTile(
                  leading: bookmark.thumbnail?.isNotEmpty == true
                      ? Image.network(
                          bookmark.thumbnail!,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(Icons.image_not_supported);
                          },
                        )
                      : const Icon(Icons.bookmark),
                  title: Text(bookmark.title),
                  subtitle: Text(bookmark.url),
                  trailing: IconButton(
                    icon: const Icon(Icons.share),
                    onPressed: () => _shareBookmark(bookmark),
                  ),
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await showDialog<String>(
            context: context,
            builder: (context) {
              final controller = TextEditingController();
              return AlertDialog(
                title: const Text('URL 입력'),
                content: TextField(
                  controller: controller,
                  decoration: const InputDecoration(hintText: 'https://...'),
                  autofocus: true,
                  onSubmitted: (value) => Navigator.pop(context, value),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('취소'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, controller.text),
                    child: const Text('확인'),
                  ),
                ],
              );
            },
          );

          if (result != null) {
            _addBookmark(result);
          }
        },
        tooltip: '북마크 추가',
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _shareBookmark(Bookmark bookmark) async {
    await Share.share(
      '${bookmark.title}\n${bookmark.url}',
      subject: bookmark.title,
    );
  }
}

class BookmarkEditDialog extends StatefulWidget {
  final Bookmark bookmark;

  const BookmarkEditDialog({super.key, required this.bookmark});

  @override
  _BookmarkEditDialogState createState() => _BookmarkEditDialogState();
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
