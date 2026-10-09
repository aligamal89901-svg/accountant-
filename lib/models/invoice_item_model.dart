/// نموذج بند الفاتورة
class InvoiceItemModel {
  final int? id;
  final int? invoiceId;
  final int productId;
  final String productName;
  final String? unitName;
  final double quantity;
  final double unitPrice;
  final double costPrice;
  final double discount;
  final double total;
  final String? notes;

  InvoiceItemModel({
    this.id,
    this.invoiceId,
    required this.productId,
    required this.productName,
    this.unitName,
    this.quantity = 1.0,
    required this.unitPrice,
    this.costPrice = 0.0,
    this.discount = 0.0,
    double? total,
    this.notes,
  }) : total = total ?? ((quantity * unitPrice) - discount);

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      if (invoiceId != null) 'invoice_id': invoiceId,
      'product_id': productId,
      'product_name': productName,
      'unit_name': unitName,
      'quantity': quantity,
      'unit_price': unitPrice,
      'cost_price': costPrice,
      'discount': discount,
      'total': total,
      'notes': notes,
    };
  }

  factory InvoiceItemModel.fromMap(Map<String, dynamic> map) {
    return InvoiceItemModel(
      id: map['id'] as int?,
      invoiceId: map['invoice_id'] as int?,
      productId: map['product_id'] as int,
      productName: map['product_name'] as String,
      unitName: map['unit_name'] as String?,
      quantity: (map['quantity'] as num).toDouble(),
      unitPrice: (map['unit_price'] as num).toDouble(),
      costPrice: (map['cost_price'] as num?)?.toDouble() ?? 0.0,
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      total: (map['total'] as num).toDouble(),
      notes: map['notes'] as String?,
    );
  }

  InvoiceItemModel copyWith({
    int? id,
    int? invoiceId,
    int? productId,
    String? productName,
    String? unitName,
    double? quantity,
    double? unitPrice,
    double? costPrice,
    double? discount,
    double? total,
    String? notes,
  }) {
    return InvoiceItemModel(
      id: id ?? this.id,
      invoiceId: invoiceId ?? this.invoiceId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      unitName: unitName ?? this.unitName,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      costPrice: costPrice ?? this.costPrice,
      discount: discount ?? this.discount,
      total: total ?? (quantity != null || unitPrice != null || discount != null
          ? ((quantity ?? this.quantity) * (unitPrice ?? this.unitPrice)) - (discount ?? this.discount)
          : this.total),
      notes: notes ?? this.notes,
    );
  }
}
