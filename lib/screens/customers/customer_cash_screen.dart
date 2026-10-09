import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/database/database_helper.dart';
import '../../models/customer_model.dart';
import '../../models/cash_box_model.dart';
import '../../models/cash_transaction_model.dart';

/// شاشة المبالغ النقدية وسندات القبض للعملاء
class CustomerCashScreen extends StatefulWidget {
  const CustomerCashScreen({super.key});

  @override
  State<CustomerCashScreen> createState() => _CustomerCashScreenState();
}

class _CustomerCashScreenState extends State<CustomerCashScreen> {
  List<CustomerModel> _customers = [];
  List<CashBoxModel> _cashBoxes = [];
  List<CashTransactionModel> _receiptTransactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final customers = await DatabaseHelper.instance.getCustomers();
    final cashBoxes = await DatabaseHelper.instance.getCashBoxes();
    final allTransactions = await DatabaseHelper.instance.getCashTransactions();
    final customerReceipts = allTransactions.where((t) => t.relatedAccountType == 'customer').toList();

    if (mounted) {
      setState(() {
        _customers = customers;
        _cashBoxes = cashBoxes;
        _receiptTransactions = customerReceipts;
        _isLoading = false;
      });
    }
  }

  void _showNewReceiptDialog() {
    CustomerModel? selectedCust = _customers.isNotEmpty ? _customers.first : null;
    CashBoxModel? selectedBox = _cashBoxes.isNotEmpty ? _cashBoxes.first : null;
    final amountController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.payments_outlined, color: AppTheme.success),
              SizedBox(width: 8),
              Text('سند قبض نقدي من عميل', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('اختر العميل والصندوق لإيداع المبلغ المستلم:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<CustomerModel?>(
                    initialValue: selectedCust,
                    decoration: const InputDecoration(labelText: 'العميل *', prefixIcon: Icon(Icons.person_outline)),
                    items: _customers.map((c) => DropdownMenuItem(value: c, child: Text('${c.name} (رصيده: ${Formatters.formatCurrency(c.currentBalance)})'))).toList(),
                    onChanged: (v) => setDialogState(() => selectedCust = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<CashBoxModel?>(
                    initialValue: selectedBox,
                    decoration: const InputDecoration(labelText: 'الصندوق المودع فيه *', prefixIcon: Icon(Icons.account_balance_wallet_outlined)),
                    items: _cashBoxes.map((b) => DropdownMenuItem(value: b, child: Text('${b.name} (${Formatters.formatCurrency(b.balance)})'))).toList(),
                    onChanged: (v) => setDialogState(() => selectedBox = v),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'المبلغ المقبوض *',
                      hintText: '0.00',
                      suffixText: 'ر.س',
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(
                      labelText: 'بيان وسند القبض',
                      hintText: 'دفعة نقدية تحت الحساب...',
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
                if (amt <= 0 || selectedCust == null || selectedBox == null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('يرجى تحديد العميل والصندوق وإدخال مبلغ صحيح'), backgroundColor: AppTheme.warning),
                  );
                  return;
                }

                final trans = CashTransactionModel(
                  cashBoxId: selectedBox!.id!,
                  type: 'إيداع',
                  amount: amt,
                  date: DateTime.now().toIso8601String().substring(0, 10),
                  description: descController.text.trim().isEmpty ? 'سند قبض من عميل: ${selectedCust!.name}' : descController.text.trim(),
                  relatedAccountType: 'customer',
                  relatedId: selectedCust!.id,
                );

                await DatabaseHelper.instance.createCashTransaction(trans);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('تم تسجيل سند القبض بمبلغ ${Formatters.formatCurrency(amt)} بنجاح'),
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
    final double totalReceipts = _receiptTransactions.fold(0.0, (sum, t) => sum + t.amount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('المبالغ النقدية وسندات القبض (العملاء)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث',
            onPressed: _loadData,
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showNewReceiptDialog,
        icon: const Icon(Icons.add),
        label: const Text('سند قبض جديد'),
        backgroundColor: AppTheme.primary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 800;
                final contentWidth = isWide ? 850.0 : double.infinity;

                return Center(
                  child: SizedBox(
                    width: contentWidth,
                    child: Column(
                      children: [
                        // ملخص إجمالي المقبوضات النقدية
                        Container(
                          margin: const EdgeInsets.all(16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.account_balance_wallet, color: AppTheme.success, size: 24),
                                  SizedBox(width: 10),
                                  Text(
                                    'إجمالي المقبوضات النقدية من العملاء:',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ],
                              ),
                              Text(
                                Formatters.formatCurrency(totalReceipts),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.success),
                              ),
                            ],
                          ),
                        ),

                        // قائمة سندات القبض
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: Row(
                            children: [
                              const Text('سجل سندات القبض والدفعات النقدية:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textSecondary)),
                              const Spacer(),
                              Text('${_receiptTransactions.length} سند', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),

                        Expanded(
                          child: _receiptTransactions.isEmpty
                              ? const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.receipt_long_outlined, size: 54, color: Colors.grey),
                                      SizedBox(height: 12),
                                      Text('لم يتم تسجيل سندات قبض بعد', style: TextStyle(color: AppTheme.textSecondary)),
                                      SizedBox(height: 6),
                                      Text('اضغط على "سند قبض جديد" لتسجيل دفعة من عميل', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  itemCount: _receiptTransactions.length,
                                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                                  itemBuilder: (ctx, i) {
                                    final trans = _receiptTransactions[i];
                                    return Container(
                                      decoration: AppTheme.cardDecoration(),
                                      child: ListTile(
                                        leading: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: AppTheme.success.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(Icons.arrow_downward, color: AppTheme.success, size: 20),
                                        ),
                                        title: Text(trans.description, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                        subtitle: Text(
                                          'تاريخ: ${trans.date} | صندوق: ${trans.cashBoxName ?? "رقم ${trans.cashBoxId}"}',
                                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                        ),
                                        trailing: Text(
                                          Formatters.formatCurrency(trans.amount),
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.success),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
