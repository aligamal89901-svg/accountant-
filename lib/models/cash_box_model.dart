/// نموذج الصندوق / الخزينة المالية
class CashBoxModel {
  final int? id;
  final String name;
  final String type; // 'نقد', 'شبكة/بطاقة', 'شيك'
  final double balance;
  final bool isDefault;
  final bool isActive;

  CashBoxModel({
    this.id,
    required this.name,
    this.type = 'نقد',
    this.balance = 0.0,
    this.isDefault = false,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'type': type,
      'balance': balance,
      'is_default': isDefault ? 1 : 0,
      'is_active': isActive ? 1 : 0,
    };
  }

  factory CashBoxModel.fromMap(Map<String, dynamic> map) {
    return CashBoxModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      type: map['type'] as String? ?? 'نقد',
      balance: (map['balance'] as num?)?.toDouble() ?? 0.0,
      isDefault: (map['is_default'] as int?) == 1,
      isActive: (map['is_active'] as int?) == 1,
    );
  }

  CashBoxModel copyWith({
    int? id,
    String? name,
    String? type,
    double? balance,
    bool? isDefault,
    bool? isActive,
  }) {
    return CashBoxModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      balance: balance ?? this.balance,
      isDefault: isDefault ?? this.isDefault,
      isActive: isActive ?? this.isActive,
    );
  }
}
