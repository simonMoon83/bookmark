class Category {
  int? id;
  String name;
  int? order;

  Category({this.id, required this.name, this.order});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'order': order,
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'],
      name: map['name'],
      order: map['order'],
    );
  }

  @override
  String toString() {
    return 'Category{id: $id, name: $name, order: $order}';
  }
}
