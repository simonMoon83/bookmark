import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/bookmark.dart';
import '../models/category.dart' as cat;
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:share_plus/share_plus.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:flutter/foundation.dart';
import '../widgets/bookmark_edit_dialog.dart';
import 'settings_screen.dart';
import 'category_screen.dart';

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
  List<cat.Category> categories = [];
  String _searchQuery = '';
  cat.Category? _selectedCategory;

  @override
  void initState() {
    super.initState();
    loadBookmarks();
    loadCategories();
    debugPrint('initState called');
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSharedFiles != oldWidget.initialSharedFiles) {
      debugPrint('didUpdateWidget: initialSharedFiles changed');
      if (widget.initialSharedFiles != null &&
          widget.initialSharedFiles!.isNotEmpty) {
        debugPrint('didUpdateWidget: processing initial shared files');
        setState(() {
          _initialSharedFilesProcessed = false;
        });
        _processInitialSharedFiles();
      } else {
        debugPrint(
            'didUpdateWidget: no initial shared files or already processed');
      }
    }
  }

  Future<void> _processInitialSharedFiles() async {
    debugPrint('_processInitialSharedFiles: start');
    if (widget.initialSharedFiles == null ||
        widget.initialSharedFiles!.isEmpty) {
      debugPrint('_processInitialSharedFiles: no files to process');
      return;
    }

    final List<SharedMediaFile> sharedFiles =
        List.from(widget.initialSharedFiles!);

    for (final file in sharedFiles) {
      if (file.type == SharedMediaType.text) {
        debugPrint(
            '_processInitialSharedFiles: adding bookmark from ${file.path}');
        final bookmark = await _addBookmark(file.path, initialLoad: true);
        if (bookmark != null && mounted) {
          await loadCategories();
          final result = await showDialog<Bookmark>(
            context: context,
            builder: (context) {
              return BookmarkEditDialog(
                  bookmark: bookmark, categories: categories);
            },
          );
          if (result != null) {
            await dbHelper.updateBookmark(result);
          }
        }
      }
    }
    if (mounted) {
      await loadBookmarks();
    }

    debugPrint('_processInitialSharedFiles: loadBookmarks completed');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          widget.initialSharedFiles?.clear();
          debugPrint('_processInitialSharedFiles: initialSharedFiles cleared');
        });
      }
    });
  }

  Future<void> loadBookmarks() async {
    debugPrint('loadBookmarks: start');
    setState(() {
      isLoading = true;
    });

    final loadedBookmarks = await dbHelper.getAllBookmarks();
    debugPrint(
        'loadBookmarks: bookmarks loaded from DB, count: ${loadedBookmarks.length}');
    List<Bookmark> filteredBookmarks = loadedBookmarks;

    debugPrint('loadBookmarks: _selectedCategory: $_selectedCategory');
    if (_selectedCategory != null) {
      if (_selectedCategory!.id != -1) {
        filteredBookmarks = filteredBookmarks
            .where((bookmark) => bookmark.categoryId == _selectedCategory!.id)
            .toList();
      }
    }

    debugPrint(
        'loadBookmarks: after category filter, count: ${filteredBookmarks.length}');

    if (_searchQuery.isNotEmpty) {
      filteredBookmarks = filteredBookmarks
          .where((bookmark) =>
              bookmark.title.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    debugPrint(
        'loadBookmarks: after search filter, count: ${filteredBookmarks.length}');

    if (!mounted) return;
    setState(() {
      bookmarks = List.from(filteredBookmarks);
      debugPrint(
          'loadBookmarks: bookmarks updated, count: ${bookmarks.length}');
      isLoading = false;
    });
    debugPrint('loadBookmarks: end');
  }

  Future<void> loadCategories() async {
    final loadedCategories = await dbHelper.getAllCategories();
    setState(() {
      categories = loadedCategories;
    });
  }

  Future<Bookmark?> _addBookmark(String url, {bool initialLoad = false}) async {
    debugPrint('_addBookmark called with url: $url, initialLoad: $initialLoad');
    if (url.isEmpty) return null;

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
            existingBookmarks.any((element) => element.url == url);
        if (!bookmarkExists) {
          final insertedId = await dbHelper.insertBookmark(bookmark);
          final newBookmark = bookmark.copyWith(id: insertedId);
          debugPrint('북마크 추가 완료');
          if (!initialLoad) {
            await loadCategories();
            final result = await showDialog<Bookmark>(
              context: context,
              builder: (context) {
                return BookmarkEditDialog(
                    bookmark: newBookmark, categories: categories);
              },
            );
            if (result != null) {
              await dbHelper.updateBookmark(result);
            }
          }
          return newBookmark;
        } else {
          debugPrint('북마크가 이미 존재합니다.');
        }
      } catch (e) {
        debugPrint('데이터베이스 삽입 오류: $e');
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
      debugPrint('_addBookmark: end');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
        'HomeScreen build method called, initialSharedFilesProcessed: $_initialSharedFilesProcessed');

    if (!_initialSharedFilesProcessed &&
        widget.initialSharedFiles != null &&
        widget.initialSharedFiles!.isNotEmpty) {
      debugPrint('build: initialSharedFiles is not empty, processing files');
      _processInitialSharedFiles();
      setState(() {
        _initialSharedFilesProcessed = true;
      });
    } else {
      debugPrint(
          'build: initialSharedFiles is null or empty or already processed');
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Easy Bookmark'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
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
                        onPressed: () =>
                            Navigator.pop(context, controller.text),
                        child: const Text('확인'),
                      ),
                    ],
                  );
                },
              );

              if (result != null) {
                final newBookmark = await _addBookmark(result);
                if (newBookmark != null && mounted) {
                  await loadBookmarks();
                }
              }
            },
            tooltip: '북마크 추가',
          ),
          IconButton(
            icon: const Icon(Icons.settings, size: 24),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              ).then((value) {
                loadCategories();
                loadBookmarks();
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.category_outlined, size: 24),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => CategoryScreen()),
              ).then((value) {
                loadCategories();
                loadBookmarks();
              });
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceVariant
                          .withOpacity(0.5),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: SearchBar(
                      hintText: '제목 검색',
                      leading: const Icon(Icons.search),
                      padding: const MaterialStatePropertyAll<EdgeInsets>(
                        EdgeInsets.symmetric(horizontal: 16.0),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                        loadBookmarks();
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceVariant
                        .withOpacity(0.5),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: PopupMenuButton<cat.Category?>(
                      initialValue: _selectedCategory,
                      tooltip: '카테고리 선택',
                      position: PopupMenuPosition.under,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.category_outlined,
                              color: _selectedCategory != null
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                            if (_selectedCategory != null) ...[
                              const SizedBox(width: 8),
                              Text(
                                _selectedCategory!.name,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      itemBuilder: (context) => [
                        PopupMenuItem<cat.Category?>(
                          value: cat.Category(id: -1, name: '전체'),
                          child: Row(
                            children: [
                              Icon(
                                Icons.all_inclusive,
                                color: _selectedCategory == null
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '전체',
                                style: TextStyle(
                                  color: _selectedCategory == null
                                      ? Theme.of(context).colorScheme.primary
                                      : null,
                                  fontWeight: _selectedCategory == null
                                      ? FontWeight.w500
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (categories.isNotEmpty) const PopupMenuDivider(),
                        ...categories.map((category) {
                          final isSelected =
                              _selectedCategory?.id == category.id;
                          return PopupMenuItem<cat.Category>(
                            value: category,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.label_outlined,
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : null,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  category.name,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.primary
                                        : null,
                                    fontWeight:
                                        isSelected ? FontWeight.w500 : null,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                      onSelected: (cat.Category? category) {
                        setState(() {
                          _selectedCategory =
                              category?.id == -1 ? null : category;
                        });
                        loadBookmarks();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    '북마크를 불러오는 중...',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
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
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '북마크가 없습니다',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '아래 + 버튼을 눌러 북마크를 추가해보세요',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
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
                        color: Theme.of(context).colorScheme.error,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Icon(Icons.delete_outline,
                            color: Theme.of(context).colorScheme.onError,
                            size: 24),
                      ),
                      direction: DismissDirection.endToStart,
                      onDismissed: (direction) async {
                        await dbHelper.deleteBookmark(bookmark.id!);
                        if (mounted) {
                          await loadBookmarks();
                        }
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('북마크가 삭제되었습니다')),
                        );
                      },
                      child: Card(
                        elevation: 2,
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
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
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: ListTile(
                              leading: bookmark.thumbnail.isNotEmpty
                                  ? Hero(
                                      tag: 'bookmark-${bookmark.id}',
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: CachedNetworkImage(
                                          imageUrl: bookmark.thumbnail,
                                          width: 60,
                                          height: 60,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) =>
                                              Container(
                                            width: 60,
                                            height: 60,
                                            decoration: BoxDecoration(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .surfaceVariant,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Center(
                                              child: SizedBox(
                                                width: 24,
                                                height: 24,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                              ),
                                            ),
                                          ),
                                          errorWidget: (context, url, error) =>
                                              Container(
                                            width: 60,
                                            height: 60,
                                            decoration: BoxDecoration(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .surfaceVariant,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              Icons.image_not_supported,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                          ),
                                        ),
                                      ),
                                    )
                                  : Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .surfaceVariant,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.bookmark,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        size: 30,
                                      ),
                                    ),
                              title: Text(
                                bookmark.title,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w500,
                                    ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  if (bookmark.categoryId != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .secondaryContainer,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          categories
                                              .firstWhere(
                                                (cat) =>
                                                    cat.id ==
                                                    bookmark.categoryId,
                                                orElse: () => cat.Category(
                                                    id: -1, name: '미분류'),
                                              )
                                              .name,
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall
                                              ?.copyWith(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSecondaryContainer,
                                              ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              trailing: PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert, size: 20),
                                  onSelected: (String value) {
                                    if (value == 'share') {
                                      _shareBookmark(bookmark);
                                    } else if (value == 'edit') {
                                      _editBookmark(bookmark);
                                    }
                                  },
                                  itemBuilder: (BuildContext context) =>
                                      <PopupMenuEntry<String>>[
                                        const PopupMenuItem<String>(
                                          value: 'share',
                                          child: Text('공유'),
                                        ),
                                        const PopupMenuItem<String>(
                                          value: 'edit',
                                          child: Text('편집'),
                                        ),
                                      ]),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Future<void> _shareBookmark(Bookmark bookmark) async {
    Share.share(
      '${bookmark.title}\n${bookmark.url}',
      subject: bookmark.title,
    );
  }

  Future<void> _editBookmark(Bookmark bookmark) async {
    final result = await showDialog<Bookmark>(
      context: context,
      builder: (context) {
        return BookmarkEditDialog(bookmark: bookmark, categories: categories);
      },
    );

    if (result != null) {
      await dbHelper.updateBookmark(result);
      if (mounted) {
        await loadBookmarks();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('북마크가 수정되었습니다')),
      );
    }
  }
}
