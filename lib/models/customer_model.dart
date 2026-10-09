/// نموذج العميل
class CustomerModel {
  final int? id;
  final String code;
  final String? barcode;
  final String name;
  final String? phone;
  final String? address;
  final String? city;
  final String? taxNumber;
  final String? crNumber;
  final int defaultPriceTier; // 1 = سعر 1، 2 = سعر 2، 3 = سعر 3
  final double? creditLimit; // الحد الأقصى للدين
  final int? dueDays; // مدة الاستحقاق بالأيام
  final String? notes;
  final String? createdAt;
  final double currentBalance; // الرصيد الحالي (موجب = عليه دين، سالب = دائن)

  // بيانات الرصيد الافتتاحي
  final double openingBalance;
  final String? openingBalanceDate;
  final String? openingBalanceNotes;

  CustomerModel({
    this.id,
    required this.code,
    this.barcode,
    required this.name,
    this.phone,
    this.address,
    this.city,
    this.taxNumber,
    this.crNumber,
    this.defaultPriceTier = 1,
    this.creditLimit,
    this.dueDays,
    this.notes,
    this.createdAt,
    this.currentBalance = 0.0,
    this.openingBalance = 0.0,
    this.openingBalanceDate,
    this.openingBalanceNotes,
  });

  bool get hasDebt => currentBalance > 0;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'code': code,
      'barcode': barcode,
      'name': name,
      'phone': phone,
      'address': address,
      'city': city,
      'tax_number': taxNumber,
      'cr_number': crNumber,
      'default_price_tier': defaultPriceTier,
      'credit_limit': creditLimit,
      'due_days': dueDays,
      'notes': notes,
      'created_at': createdAt ?? DateTime.now().toIso8601String(),
      'opening_balance': openingBalance,
      'opening_balance_date': openingBalanceDate,
      'opening_balance_notes': openingBalanceNotes,
    };
  }

  factory CustomerModel.fromMap(Map<String, dynamic> map, {double balance = 0.0}) {
    return CustomerModel(
      id: map['id'] as int?,
      code: map['code'] as String? ?? '',
      barcode: map['barcode'] as String?,
      name: map['name'] as String,
      phone: map['phone'] as String?,
      address: map['address'] as String?,
      city: map['city'] as String?,
      taxNumber: map['tax_number'] as String?,
      crNumber: map['cr_number'] as String?,
      defaultPriceTier: (map['default_price_tier'] as int?) ?? 1,
      creditLimit: (map['credit_limit'] as num?)?.toDouble(),
      dueDays: map['due_days'] as int?,
      notes: map['notes'] as String?,
      createdAt: map['created_at'] as String?,
      openingBalance: (map['opening_balance'] as num?)?.toDouble() ?? 0.0,
      openingBalanceDate: map['opening_balance_date'] as String?,
      openingBalanceNotes: map['opening_balance_notes'] as String?,
      currentBalance: balance,
    );
  }

  CustomerModel copyWith({
    int? id,
    String? code,
    String? barcode,
    String? name,
    String? phone,
    String? address,
    String? city,
    String? taxNumber,
    String? crNumber,
    int? defaultPriceTier,
    double? creditLimit,
    int? dueDays,
    String? notes,
    String? createdAt,
    double? currentBalance,
    double? openingBalance,
    String? openingBalanceDate,
    String? openingBalanceNotes,
  }) {
    return CustomerModel(
      id: id ?? this.id,
      code: code ?? this.code,
      barcode: barcode ?? this.barcode,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      city: city ?? this.city,
      taxNumber: taxNumber ?? this.taxNumber,
      crNumber: crNumber ?? this.crNumber,
      defaultPriceTier: defaultPriceTier ?? this.defaultPriceTier,
      creditLimit: creditLimit ?? this.creditLimit,
      dueDays: dueDays ?? this.dueDays,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      currentBalance: currentBalance ?? this.currentBalance,
      openingBalance: openingBalance ?? this.openingBalance,
      openingBalanceDate: openingBalanceDate ?? this.openingBalanceDate,
      openingBalanceNotes: openingBalanceNotes ?? this.openingBalanceNotes,
    );
  }
}
