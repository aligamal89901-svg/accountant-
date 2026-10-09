/// نموذج حركة الصندوق (إيداع / صرف)
class CashTransactionModel {
  final int? id;
  final int cashBoxId;
  final String type; // 'إيداع', 'صرف'
  final double amount;
  final String date;
  final String description;
  final String? relatedAccountType; // 'عميل', 'مورد', 'فاتورة', 'مصروف', 'عام'
  final int? relatedId;
  final String? createdAt;

  // حقل مساعد للعرض
  final String? cashBoxName;

  CashTransactionModel({
    this.id,
    required this.cashBoxId,
    required this.type,
    required this.amount,
    required this.date,
    required this.description,
    this.relatedAccountType,
    this.relatedId,
    this.createdAt,
    this.cashBoxName,
  });

  bool get isDeposit => type == 'إيداع';

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'cash_box_id': cashBoxId,
      'type': type,
      'amount': amount,
      'date': date,
      'description': description,
      'related_account_type': relatedAccountType,
      'related_id': relatedId,
      'created_at': createdAt ?? DateTime.now().toIso8601String(),
    };
  }

  factory CashTransactionModel.fromMap(Map<String, dynamic> map) {
    return CashTransactionModel(
      id: map['id'] as int?,
      cashBoxId: map['cash_box_id'] as int,
      type: map['type'] as String,
      amount: (map['amount'] as num).toDouble(),
      date: map['date'] as String,
      description: map['description'] as String,
      relatedAccountType: map['related_account_type'] as String?,
      relatedId: map['related_id'] as int?,
      createdAt: map['created_at'] as String?,
      cashBoxName: map['cash_box_name'] as String?,
    );
  }
}
