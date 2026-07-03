/// 账本模型
class Book {
  final int id;
  final String name;
  final int category;
  final String? categoryName;
  final int sortOrder;
  final int assetCount;
  final double? totalMarketValue;

  const Book({
    required this.id,
    required this.name,
    required this.category,
    this.categoryName,
    this.sortOrder = 0,
    this.assetCount = 0,
    this.totalMarketValue,
  });

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      category: json['category'] as int? ?? 0,
      categoryName: json['categoryName'] as String?,
      sortOrder: json['sortOrder'] as int? ?? 0,
      assetCount: json['assetCount'] as int? ?? 0,
      totalMarketValue: (json['totalMarketValue'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category,
    'sortOrder': sortOrder,
  };
}

/// 创建/更新账本请求
class BookRequest {
  final String name;
  final int category;

  const BookRequest({required this.name, required this.category});

  Map<String, dynamic> toJson() => {
    'name': name,
    'category': category,
  };
}
