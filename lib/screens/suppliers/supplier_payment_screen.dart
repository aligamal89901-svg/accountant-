import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/database/database_helper.dart';
import '../../models/supplier_model.dart';
import '../../models/cash_box_model.dart';
import '../../models/cash_transaction_model.dart';

/// شاشة تسجيل المدفوعات للموردين (سندات الصرف النقدية)
class SupplierPaymentScreen extends StatefulWidget {
  const SupplierPaymentScreen({super.key});

  @override
  State<SupplierPaymentScreen> createState() => _SupplierPaymentScreenState();
}

class _SupplierPaymentScreenState extends State<SupplierPaymentScreen> {
  List<SupplierModel> _suppliers = [];
  List<CashBoxModel> _cashBoxes = [];
  List<CashTransactionModel> _paymentTransactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final suppliers = await DatabaseHelper.instance.getSuppliers();
    final cashBoxes = await DatabaseHelper.instance.getCashBoxes();
    final allTransactions = await DatabaseHelper.instance.getCashTransactions();
    final supplierPayments = allTransactions.where((t) => t.relatedAccountType == 'supplier').toList();

    if (mounted) {
      setState(() {
        _suppliers = suppliers;
        _cashBoxes = cashBoxes;
        _paymentTransactions = supplierPayments;
        _isLoading = false;
      });
    }
  }

  void _showNewPaymentDialog() {
    SupplierModel? selectedSupp = _suppliers.isNotEmpty ? _suppliers.first : null;
    CashBoxModel? selectedBox = _cashBoxes.isNotEmpty ? _cashBoxes.first : null;
    final amountController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.payments_outlined, color: AppTheme.danger),
              SizedBox(width: 8),
              Text('سند صرف نقدي لمورد', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('اختر المورد والصندوق لصرف المبلغ المدفوع:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<SupplierModel?>(
                    initialValue: selectedSupp,
                    decoration: const InputDecoration(labelText: 'المورد *', prefixIcon: Icon(Icons.store_outlined)),
                    items: _suppliers.map((s) => DropdownMenuItem(value: s, child: Text('${s.name} (مستحقاته: ${Formatters.formatCurrency(s.currentBalance)})'))).toList(),
                    onChanged: (v) => setDialogState(() => selectedSupp = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<CashBoxModel?>(
                    initialValue: selectedBox,
                    decoration: const InputDecoration(labelText: 'الصندوق المصروف منه *', prefixIcon: Icon(Icons.account_balance_wallet_outlined)),
                    items: _cashBoxes.map((b) => DropdownMenuItem(value: b, child: Text('${b.name} (${Formatters.formatCurrency(b.balance)})'))).toList(),
                    onChanged: (v) => setDialogState(() => selectedBox = v),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'المبلغ المدفوع *',
                      hintText: '0.00',
                      suffixText: 'ر.س',
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(
                      labelText: 'بيان وسند الصرف',
                      hintText: 'دفعة سداد حساب مشتريات...',
                      prefixIcon: Icon(Icons.notes_outlined),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                final amt = double.tryParse(amountController.text.trim()) ?? 0.0;
                if (amt <= 0 || selectedSupp == null || selectedBox == null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('يرجى تحديد المورد والصندوق وإدخال مبلغ صحيح'), backgroundColor: AppTheme.warning),
                  );
                  return;
                }

                if (selectedBox!.balance < amt) {
                  final proceed = await showDialog<bool>(
                    context: ctx,
                    builder: (c) => AlertDialog(
                      title: const Text('رصيد الصندوق غير كافٍ'),
                      content: Text('رصيد الصندوق (${Formatters.formatCurrency(selectedBox!.balance)}) أقل من المبلغ المراد صرفه (${Formatters.formatCurrency(amt)}). هل تريد المتابعة وجعل رصيد الصندوق سالب؟'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('تراجع')),
                        ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('متابعة الصرف')),
                      ],
                    ),
                  );
                  if (proceed != true) return;
                }

                final trans = CashTransactionModel(
                  cashBoxId: selectedBox!.id!,
                  type: 'صرف',
                  amount: amt,
                  date: DateTime.now().toIso8601String().substring(0, 10),
                  description: descController.text.trim().isEmpty ? 'سند صرف لمورد: ${selectedSupp!.name}' : descController.text.trim(),
                  relatedAccountType: 'supplier',
                  relatedId: selectedSupp!.id,
                );

                await DatabaseHelper.instance.createCashTransaction(trans);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('تم تسجيل سند الصرف بمبلغ ${Formatters.formatCurrency(amt)} بنجاح'),
                      backgroundColor: AppTheme.success,
                    ),
                  );
                  _loadData();
                }
              },
              child: const Text('حفظ السند'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalPaid = _paymentTransactions.fold(0.0, (sum, t) => sum + t.amount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('تسجيل المدفوعات للموردين (سندات الصرف)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'تحديث',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showNewPaymentDialog,
        icon: const Icon(Icons.add),
        label: const Text('سند صرف جديد'),
        backgroundColor: AppTheme.primary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // بطاقة ملخص المدفوعات
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Theme.of(context).cardColor,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Text('إجمالي سندات الصرف', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                          const SizedBox(height: 4),
                          Text(
                            '${_paymentTransactions.length} سند',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Container(height: 30, width: 1, color: Colors.grey.shade300),
                      Column(
                        children: [
                          const Text('إجمالي المبالغ المدفوعة', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                          const SizedBox(height: 4),
                          Text(
                            Formatters.formatCurrency(totalPaid),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.danger),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // قائمة السندات السابقة
                Expanded(
                  child: _paymentTransactions.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.payments_outlined, size: 64, color: Colors.grey.shade300),
                              const SizedBox(height: 12),
                              const Text('لا توجد سندات صرف مسجلة حتى الآن'),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: _showNewPaymentDialog,
                                icon: const Icon(Icons.add),
                                label: const Text('تسجيل أول سند صرف'),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _paymentTransactions.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final t = _paymentTransactions[index];
                            final supplier = _suppliers.cast<SupplierModel?>().firstWhere(
                                  (s) => s?.id == t.relatedId,
                                  orElse: () => null,
                                );

                            return Card(
                              child: ListTile(
                                leading: const CircleAvatar(
                                  backgroundColor: Color(0xFFFEE2E2),
                                  child: Icon(Icons.arrow_upward, color: AppTheme.danger),
                                ),
                                title: Text(
                                  supplier != null ? supplier.name : (t.description.isNotEmpty ? t.description : 'سند صرف لمورد'),
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  'التاريخ: ${t.date} ${t.cashBoxName != null ? "• الصندوق: ${t.cashBoxName}" : ""}\n${t.description}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                isThreeLine: t.description.isNotEmpty,
                                trailing: Text(
                                  Formatters.formatCurrency(t.amount),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: AppTheme.danger,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
