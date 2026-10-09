/// نموذج المنتج والمخزون المالي والتجاري المتكامل
class ProductModel {
  final int? id;
  final String barcode;
  final String name;
  final int? categoryId;
  final int? unitId;
  final double salePrice1;
  final double? salePrice2;
  final double? salePrice3;
  final double costPrice;
  final double stockQuantity;
  final double minQuantity;
  final double taxPercent;
  final String status; // 'متوفر', 'مجمد', 'غير متوفر'
  final String? notes;
  final String? createdAt;

  // الحقول الموسعة (الوزن، الوصف، الصورة، الرقم التسلسلي، الرصيد الافتتاحي)
  final double? weight;
  final String? description;
  final String? imagePath;
  final String? serialNumber;
  final double? openingStock;

  // حقول مساعدة من الـ JOIN
  final String? categoryName;
  final String? unitName;

  ProductModel({
    this.id,
    required this.barcode,
    required this.name,
    this.categoryId,
    this.unitId,
    required this.salePrice1,
    this.salePrice2,
    this.salePrice3,
    required this.costPrice,
    this.stockQuantity = 0.0,
    this.minQuantity = 5.0,
    this.taxPercent = 0.0,
    this.status = 'متوفر',
    this.notes,
    this.createdAt,
    this.weight,
    this.description,
    this.imagePath,
    this.serialNumber,
    this.openingStock,
    this.categoryName,
    this.unitName,
  });

  bool get isLowStock => stockQuantity <= minQuantity && stockQuantity > 0;
  bool get isOutOfStock => stockQuantity <= 0;
  bool get isFrozen => status == 'مجمد';

  /// الحصول على سعر البيع حسب فئة التسعير (1: مفرق، 2: جملة، 3: خاص)
  double getPriceForTier(int tier) {
    switch (tier) {
      case 2:
        return (salePrice2 != null && salePrice2! > 0) ? salePrice2! : salePrice1;
      case 3:
        return (salePrice3 != null && salePrice3! > 0) ? salePrice3! : salePrice1;
      case 1:
      default:
        return salePrice1;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'barcode': barcode,
      'name': name,
      'category_id': categoryId,
      'unit_id': unitId,
      'sale_price1': salePrice1,
      'sale_price2': salePrice2,
      'sale_price3': salePrice3,
      'cost_price': costPrice,
      'stock_quantity': stockQuantity,
      'min_quantity': minQuantity,
      'tax_percent': taxPercent,
      'status': status,
      'notes': notes,
      'created_at': createdAt ?? DateTime.now().toIso8601String(),
      'weight': weight,
      'description': description,
      'image_path': imagePath,
      'serial_number': serialNumber,
      'opening_stock': openingStock ?? stockQuantity,
    };
  }

  factory ProductModel.fromMap(Map<String, dynamic> map) {
    return ProductModel(
      id: map['id'] as int?,
      barcode: map['barcode'] as String? ?? '',
      name: map['name'] as String,
      categoryId: map['category_id'] as int?,
      unitId: map['unit_id'] as int?,
      salePrice1: (map['sale_price1'] as num).toDouble(),
      salePrice2: (map['sale_price2'] as num?)?.toDouble(),
      salePrice3: (map['sale_price3'] as num?)?.toDouble(),
      costPrice: (map['cost_price'] as num?)?.toDouble() ?? 0.0,
      stockQuantity: (map['stock_quantity'] as num?)?.toDouble() ?? 0.0,
      minQuantity: (map['min_quantity'] as num?)?.toDouble() ?? 5.0,
      taxPercent: (map['tax_percent'] as num?)?.toDouble() ?? 0.0,
      status: map['status'] as String? ?? 'متوفر',
      notes: map['notes'] as String?,
      createdAt: map['created_at'] as String?,
      weight: (map['weight'] as num?)?.toDouble(),
      description: map['description'] as String?,
      imagePath: map['image_path'] as String?,
      serialNumber: map['serial_number'] as String?,
      openingStock: (map['opening_stock'] as num?)?.toDouble(),
      categoryName: map['category_name'] as String?,
      unitName: map['unit_name'] as String?,
    );
  }

  ProductModel copyWith({
    int? id,
    String? barcode,
    String? name,
    int? categoryId,
    int? unitId,
    double? salePrice1,
    double? salePrice2,
    double? salePrice3,
    double? costPrice,
    double? stockQuantity,
    double? minQuantity,
    double? taxPercent,
    String? status,
    String? notes,
    String? createdAt,
    double? weight,
    String? description,
    String? imagePath,
    String? serialNumber,
    double? openingStock,
    String? categoryName,
    String? unitName,
  }) {
    return ProductModel(
      id: id ?? this.id,
      barcode: barcode ?? this.barcode,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      unitId: unitId ?? this.unitId,
      salePrice1: salePrice1 ?? this.salePrice1,
      salePrice2: salePrice2 ?? this.salePrice2,
      salePrice3: salePrice3 ?? this.salePrice3,
      costPrice: costPrice ?? this.costPrice,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      minQuantity: minQuantity ?? this.minQuantity,
      taxPercent: taxPercent ?? this.taxPercent,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      weight: weight ?? this.weight,
      description: description ?? this.description,
      imagePath: imagePath ?? this.imagePath,
      serialNumber: serialNumber ?? this.serialNumber,
      openingStock: openingStock ?? this.openingStock,
      categoryName: categoryName ?? this.categoryName,
      unitName: unitName ?? this.unitName,
    );
  }
}
