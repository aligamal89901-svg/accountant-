/// نموذج المورد
class SupplierModel {
  final int? id;
  final String code;
  final String name;
  final String? phone;
  final String? address;
  final String? taxNumber;
  final String? crNumber;
  final String? notes;
  final String? createdAt;
  final double currentBalance; // الرصيد الحالي (موجب = له مستحقات علينا)

  // بيانات الرصيد الافتتاحي
  final double openingBalance;
  final String? openingBalanceDate;
  final String? openingBalanceNotes;

  SupplierModel({
    this.id,
    required this.code,
    required this.name,
    this.phone,
    this.address,
    this.taxNumber,
    this.crNumber,
    this.notes,
    this.createdAt,
    this.currentBalance = 0.0,
    this.openingBalance = 0.0,
    this.openingBalanceDate,
    this.openingBalanceNotes,
  });

  bool get hasPayables => currentBalance > 0;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'code': code,
      'name': name,
      'phone': phone,
      'address': address,
      'tax_number': taxNumber,
      'cr_number': crNumber,
      'notes': notes,
      'created_at': createdAt ?? DateTime.now().toIso8601String(),
      'opening_balance': openingBalance,
      'opening_balance_date': openingBalanceDate,
      'opening_balance_notes': openingBalanceNotes,
    };
  }

  factory SupplierModel.fromMap(Map<String, dynamic> map, {double balance = 0.0}) {
    return SupplierModel(
      id: map['id'] as int?,
      code: map['code'] as String? ?? '',
      name: map['name'] as String,
      phone: map['phone'] as String?,
      address: map['address'] as String?,
      taxNumber: map['tax_number'] as String?,
      crNumber: map['cr_number'] as String?,
      notes: map['notes'] as String?,
      createdAt: map['created_at'] as String?,
      openingBalance: (map['opening_balance'] as num?)?.toDouble() ?? 0.0,
      openingBalanceDate: map['opening_balance_date'] as String?,
      openingBalanceNotes: map['opening_balance_notes'] as String?,
      currentBalance: balance,
    );
  }

  SupplierModel copyWith({
    int? id,
    String? code,
    String? name,
    String? phone,
    String? address,
    String? taxNumber,
    String? crNumber,
    String? notes,
    String? createdAt,
    double? currentBalance,
    double? openingBalance,
    String? openingBalanceDate,
    String? openingBalanceNotes,
  }) {
    return SupplierModel(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      taxNumber: taxNumber ?? this.taxNumber,
      crNumber: crNumber ?? this.crNumber,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      currentBalance: currentBalance ?? this.currentBalance,
      openingBalance: openingBalance ?? this.openingBalance,
      openingBalanceDate: openingBalanceDate ?? this.openingBalanceDate,
      openingBalanceNotes: openingBalanceNotes ?? this.openingBalanceNotes,
    );
  }
}
