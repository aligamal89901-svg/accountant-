/// نموذج تصنيف المنتجات
class CategoryModel {
  final int? id;
  final String name;
  final bool isActive;

  CategoryModel({
    this.id,
    required this.name,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'is_active': isActive ? 1 : 0,
    };
  }

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      isActive: (map['is_active'] as int?) == 1,
    );
  }

  CategoryModel copyWith({
    int? id,
    String? name,
    bool? isActive,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
    );
  }
}
