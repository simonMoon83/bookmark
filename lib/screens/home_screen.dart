import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/bookmark.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:share_plus/share_plus.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:flutter/foundation.dart';

class HomeScreen extends StatefulWidget {
  final List<SharedMediaFile>? initialSharedFiles;
  const HomeScreen({super.key, this.initialSharedFiles});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final dbHelper = DatabaseHelper.instance;
  List<Bookmark> bookmarks = [];
  bool isLoading = false;
  bool _initialSharedFilesProcessed = false;

  @override
  void initState() {
    super.initState();
    loadBookmarks();
    debugPrint('initState called');
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSharedFiles != oldWidget.initialSharedFiles) {
      if (widget.initialSharedFiles != null &&
          widget.initialSharedFiles!.isNotEmpty &&
          !_initialSharedFilesProcessed) {
        setState(() {
          _initialSharedFilesProcessed = true;
        });
        _processInitialSharedFiles();
      }
    }
  }

  Future<void> _processInitialSharedFiles() async {
    if (widget.initialSharedFiles == null || widget.initialSharedFiles!.isEmpty)
      return;

    for (final file in widget.initialSharedFiles!) {
      if (file.type == SharedMediaType.text) {
        debugPrint('Adding bookmark from initial shared file: ${file.path}');
        await _addBookmark(file.path, initialLoad: true);
      }
    }
    await loadBookmarks();
    // Clear the initialSharedFiles after processing
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          widget.initialSharedFiles?.clear();
        });
      }
    });
  }

  Future<void> loadBookmarks() async {
    setState(() {
      isLoading = true;
    });

    final loadedBookmarks = await dbHelper.getAllBookmarks();

    if (!mounted) return;
    setState(() {
      bookmarks = loadedBookmarks.map((map) => Bookmark.fromMap(map)).toList();
      isLoading = false;
    });
  }

  Future<void> _addBookmark(String url, {bool initialLoad = false}) async {
    debugPrint('_addBookmark called with url: $url, initialLoad: $initialLoad');
    if (url.isEmpty) return;

    setState(() {
      isLoading = true;
    });

    try {
      String title = '';
      String thumbnailUrl = '';
      bool isYouTube = url.contains('youtube.com') || url.contains('youtu.be');

      debugPrint('URL: $url, isYouTube: $isYouTube');

      String parsedUrl = url;
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        parsedUrl = 'https://$url';
      }

      if (isYouTube) {
        final yt = YoutubeExplode();
        debugPrint('유튜브 정보 가져오기 시작');
        try {
          final video = await yt.videos.get(parsedUrl);
          title = video.title;
          thumbnailUrl = video.thumbnails.highResUrl;
          yt.close();
          debugPrint(
              '유튜브 정보 가져오기 완료: title: $title, thumbnailUrl: $thumbnailUrl');
        } catch (e) {
          debugPrint('유튜브 정보 가져오기 오류: $e');
          // 일반적인 웹페이지로 처리
          isYouTube = false;
        }
      }

      if (!isYouTube) {
        debugPrint('웹페이지 정보 가져오기 시작');
        final response = await http.get(Uri.parse(parsedUrl));
        debugPrint('웹페이지 정보 가져오기 완료: statusCode: ${response.statusCode}');
        if (response.statusCode == 200) {
          final document = parser.parse(response.body);
          final titleElement = document.querySelector('title');
          title = titleElement?.text ?? url;

          // Open Graph 이미지 찾기
          final ogImage = document.querySelector('meta[property="og:image"]');
          thumbnailUrl = ogImage?.attributes['content'] ?? '';
          debugPrint(
              '웹페이지 정보 파싱 완료: title: $title, thumbnailUrl: $thumbnailUrl');
        }
      }

      final bookmark = Bookmark(
        url: url,
        title: title,
        thumbnail: thumbnailUrl,
        description: title,
        createdAt: DateTime.now(),
      );

      debugPrint('북마크 객체 생성 완료: $bookmark');
      debugPrint('북마크 추가 시도 직전: $bookmark');
      debugPrint('북마크 추가 시도: $bookmark');
      try {
        // Check if bookmark already exists
        final existingBookmarks = await dbHelper.getAllBookmarks();
        final bookmarkExists =
            existingBookmarks.any((element) => element['url'] == url);
        if (!bookmarkExists) {
          await dbHelper.insertBookmark(bookmark.toMap());
          debugPrint('북마크 추가 완료');
        } else {
          debugPrint('북마크가 이미 존재합니다.');
        }
      } catch (e) {
        debugPrint('데이터베이스 삽입 오류: $e');
      }
      if (!initialLoad) {
        await loadBookmarks();
      }

      if (mounted && !initialLoad) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('북마크가 추가되었습니다: ${bookmark.title}')),
        );
      }
    } catch (e) {
      debugPrint('북마크 추가 중 오류 발생: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('북마크 추가 중 오류가 발생했습니다.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('HomeScreen build method called');
    debugPrint('initialSharedFilesProcessed: $_initialSharedFilesProcessed');
    if (!_initialSharedFilesProcessed &&
        widget.initialSharedFiles != null &&
        widget.initialSharedFiles!.isNotEmpty) {
      debugPrint('initialSharedFiles is not empty');

      _initialSharedFilesProcessed = true;
      _processInitialSharedFiles();
    } else {
      debugPrint('initialSharedFiles is null or empty or already processed');
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('북마크'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close, size: 24),
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
                loadBookmarks();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('모든 북마크가 삭제되었습니다')),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_outlined, size: 24),
            onPressed: loadBookmarks,
          ),
        ],
      ),
      body: isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('북마크를 불러오는 중...'),
                ],
              ),
            )
          : bookmarks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.bookmark_border_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '북마크가 없습니다',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '아래 + 버튼을 눌러 북마크를 추가해보세요',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: bookmarks.length,
                  itemBuilder: (context, index) {
                    final bookmark = bookmarks[index];
                    return Dismissible(
                      key: Key(bookmark.id.toString()),
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: const Icon(Icons.delete_outline,
                            color: Colors.white, size: 24),
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
                        margin: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        child: InkWell(
                          onTap: () async {
                            try {
                              final url = Uri.parse(bookmark.url);

                              if (bookmark.url.contains('youtu.be') ||
                                  bookmark.url.contains('youtube.com')) {
                                if (await canLaunchUrl(url)) {
                                  await launchUrl(
                                    url,
                                    mode: LaunchMode
                                        .externalNonBrowserApplication,
                                  );
                                } else {
                                  if (await canLaunchUrl(url)) {
                                    await launchUrl(url,
                                        mode: LaunchMode.externalApplication);
                                  }
                                }
                              } else {
                                if (await canLaunchUrl(url)) {
                                  await launchUrl(
                                    url,
                                    mode: LaunchMode.externalApplication,
                                  );
                                }
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('URL을 열 수 없습니다: $e')),
                                );
                              }
                            }
                          },
                          child: ListTile(
                            leading: bookmark.thumbnail.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: CachedNetworkImage(
                                      imageUrl: bookmark.thumbnail,
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) =>
                                          const Center(
                                        child: SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      ),
                                      errorWidget: (context, url, error) =>
                                          Container(
                                        width: 50,
                                        height: 50,
                                        color: Colors.grey[200],
                                        child: const Icon(
                                          Icons.image_not_supported,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                  )
                                : Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Icon(
                                      Icons.bookmark,
                                      color: Colors.grey,
                                    ),
                                  ),
                            title: Text(bookmark.title),
                            subtitle: Text(bookmark.url),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon:
                                      const Icon(Icons.edit_outlined, size: 22),
                                  onPressed: () async {
                                    // 편집 기능 구현
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.share_outlined,
                                      size: 22),
                                  onPressed: () => _shareBookmark(bookmark),
                                ),
                              ],
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
                  decoration: const InputDecoration(
                    hintText: 'https://...',
                    prefixIcon: Icon(Icons.link_outlined),
                  ),
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
    Share.share(
      '${bookmark.title}\n${bookmark.url}',
      subject: bookmark.title,
    );
  }
}
