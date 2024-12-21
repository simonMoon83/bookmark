class Bookmark {
  final int? id;
  final String title;
  final String url;
  final String thumbnail;
  final String description;
  final DateTime createdAt;
  final int? categoryId;

  Bookmark({
    this.id,
    required this.title,
    required this.url,
    required this.thumbnail,
    required this.description,
    required this.createdAt,
    this.categoryId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'url': url,
      'thumbnail': thumbnail,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'categoryId': categoryId,
    };
  }

  factory Bookmark.fromMap(Map<String, dynamic> map) {
    return Bookmark(
      id: map['id'],
      title: map['title'],
      url: map['url'],
      thumbnail: map['thumbnail'],
      description: map['description'],
      createdAt: DateTime.parse(map['createdAt']),
      categoryId: map['categoryId'],
    );
  }

  Bookmark copyWith({
    int? id,
    String? title,
    String? url,
    String? thumbnail,
    String? description,
    DateTime? createdAt,
    int? categoryId,
  }) {
    return Bookmark(
      id: id ?? this.id,
      title: title ?? this.title,
      url: url ?? this.url,
      thumbnail: thumbnail ?? this.thumbnail,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      categoryId: categoryId ?? this.categoryId,
    );
  }
}
