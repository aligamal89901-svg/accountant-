import 'invoice_item_model.dart';

/// نموذج الفاتورة (مبيعات / مشتريات)
class InvoiceModel {
  final int? id;
  final String invoiceNumber;
  final String type; // 'sale', 'purchase'
  final int? customerId;
  final int? supplierId;
  final String date;
  final double subtotal;
  final double discount;
  final double tax;
  final double total;
  final double paid;
  final double remaining;
  final String paymentMethod; // 'نقد', 'شبكة/بطاقة', 'شيك', 'آجل/ذمة'
  final int? cashBoxId;
  final String? notes;
  final String status; // 'مكتملة', 'ملغاة', 'مرتجعة'
  final String? createdAt;

  // حقول مساعدة للعرض
  final String? customerName;
  final String? supplierName;
  final List<InvoiceItemModel> items;

  InvoiceModel({
    this.id,
    required this.invoiceNumber,
    this.type = 'sale',
    this.customerId,
    this.supplierId,
    required this.date,
    required this.subtotal,
    this.discount = 0.0,
    this.tax = 0.0,
    required this.total,
    required this.paid,
    double? remaining,
    this.paymentMethod = 'نقد',
    this.cashBoxId,
    this.notes,
    this.status = 'مكتملة',
    this.createdAt,
    this.customerName,
    this.supplierName,
    this.items = const [],
  }) : remaining = remaining ?? (total - paid);

  bool get isPaidInFull => remaining <= 0.001;
  bool get hasRemaining => remaining > 0.001;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'invoice_number': invoiceNumber,
      'type': type,
      'customer_id': customerId,
      'supplier_id': supplierId,
      'date': date,
      'subtotal': subtotal,
      'discount': discount,
      'tax': tax,
      'total': total,
      'paid': paid,
      'remaining': remaining,
      'payment_method': paymentMethod,
      'cash_box_id': cashBoxId,
      'notes': notes,
      'status': status,
      'created_at': createdAt ?? DateTime.now().toIso8601String(),
    };
  }

  factory InvoiceModel.fromMap(Map<String, dynamic> map, {List<InvoiceItemModel> items = const []}) {
    return InvoiceModel(
      id: map['id'] as int?,
      invoiceNumber: map['invoice_number'] as String,
      type: map['type'] as String? ?? 'sale',
      customerId: map['customer_id'] as int?,
      supplierId: map['supplier_id'] as int?,
      date: map['date'] as String,
      subtotal: (map['subtotal'] as num).toDouble(),
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      tax: (map['tax'] as num?)?.toDouble() ?? 0.0,
      total: (map['total'] as num).toDouble(),
      paid: (map['paid'] as num).toDouble(),
      remaining: (map['remaining'] as num?)?.toDouble(),
      paymentMethod: map['payment_method'] as String? ?? 'نقد',
      cashBoxId: map['cash_box_id'] as int?,
      notes: map['notes'] as String?,
      status: map['status'] as String? ?? 'مكتملة',
      createdAt: map['created_at'] as String?,
      customerName: map['customer_name'] as String?,
      supplierName: map['supplier_name'] as String?,
      items: items,
    );
  }

  InvoiceModel copyWith({
    int? id,
    String? invoiceNumber,
    String? type,
    int? customerId,
    int? supplierId,
    String? date,
    double? subtotal,
    double? discount,
    double? tax,
    double? total,
    double? paid,
    double? remaining,
    String? paymentMethod,
    int? cashBoxId,
    String? notes,
    String? status,
    String? createdAt,
    String? customerName,
    String? supplierName,
    List<InvoiceItemModel>? items,
  }) {
    return InvoiceModel(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      type: type ?? this.type,
      customerId: customerId ?? this.customerId,
      supplierId: supplierId ?? this.supplierId,
      date: date ?? this.date,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      tax: tax ?? this.tax,
      total: total ?? this.total,
      paid: paid ?? this.paid,
      remaining: remaining ?? this.remaining,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      cashBoxId: cashBoxId ?? this.cashBoxId,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      customerName: customerName ?? this.customerName,
      supplierName: supplierName ?? this.supplierName,
      items: items ?? this.items,
    );
  }
}
