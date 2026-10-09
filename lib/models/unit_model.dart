/// نموذج وحدة القياس (قطعة، كرتون، كيس...) قابلة للإضافة والتوسيع
class UnitModel {
  final int? id;
  final String name;
  final bool isActive;

  UnitModel({
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

  factory UnitModel.fromMap(Map<String, dynamic> map) {
    return UnitModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      isActive: (map['is_active'] as int?) == 1,
    );
  }

  UnitModel copyWith({
    int? id,
    String? name,
    bool? isActive,
  }) {
    return UnitModel(
      id: id ?? this.id,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
    );
  }
}
