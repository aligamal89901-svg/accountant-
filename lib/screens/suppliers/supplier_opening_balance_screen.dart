import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/database/database_helper.dart';
import '../../models/supplier_model.dart';

/// شاشة إدارة الأرصدة الافتتاحية للموردين
class SupplierOpeningBalanceScreen extends StatefulWidget {
  const SupplierOpeningBalanceScreen({super.key});

  @override
  State<SupplierOpeningBalanceScreen> createState() => _SupplierOpeningBalanceScreenState();
}

class _SupplierOpeningBalanceScreenState extends State<SupplierOpeningBalanceScreen> {
  List<SupplierModel> _suppliers = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
  }

  Future<void> _loadSuppliers() async {
    setState(() => _isLoading = true);
    final suppliers = await DatabaseHelper.instance.getSuppliers();
    if (mounted) {
      setState(() {
        _suppliers = suppliers;
        _isLoading = false;
      });
    }
  }

  void _showEditOpeningBalanceDialog(SupplierModel supplier) {
    final amountController = TextEditingController(
      text: supplier.openingBalance > 0 ? supplier.openingBalance.toString() : '',
    );
    final notesController = TextEditingController(text: supplier.openingBalanceNotes ?? '');
    String selectedDate = supplier.openingBalanceDate ?? DateTime.now().toIso8601String().substring(0, 10);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.account_balance_wallet_outlined, color: AppTheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text('الرصيد الافتتاحي: ${supplier.name}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'الرصيد الافتتاحي هو المبلغ المستحق للمورد علينا قبل بدء استخدام النظام:',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: amountController,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'المبلغ المستحق الافتتاحي (دائن) *',
                      hintText: '0.00',
                      suffixText: 'ر.س',
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 18, color: AppTheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('تاريخ الرصيد: $selectedDate', style: const TextStyle(fontSize: 13)),
                      ),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              selectedDate = picked.toIso8601String().substring(0, 10);
                            });
                          }
                        },
                        child: const Text('تغيير التاريخ'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظات الرصيد الافتتاحي',
                      hintText: 'رصيد منقول من الدفاتر السابقة...',
                      prefixIcon: Icon(Icons.notes_outlined),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                final amt = double.tryParse(amountController.text.trim()) ?? 0.0;
                await DatabaseHelper.instance.setSupplierOpeningBalance(
                  supplierId: supplier.id!,
                  amount: amt,
                  date: selectedDate,
                  notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                );
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('تم تحديث الرصيد الافتتاحي للمورد: ${supplier.name}'),
                      backgroundColor: AppTheme.success,
                    ),
                  );
                  _loadSuppliers();
                }
              },
              child: const Text('حفظ الرصيد'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _suppliers.where((s) {
      final q = _searchQuery.toLowerCase();
      return s.name.toLowerCase().contains(q) ||
          s.code.toLowerCase().contains(q) ||
          (s.phone?.contains(q) ?? false);
    }).toList();

    final totalOpening = filtered.fold(0.0, (sum, s) => sum + s.openingBalance);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الأرصدة الافتتاحية للموردين'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSuppliers,
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // شريط البحث والملخص
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Theme.of(context).cardColor,
                  child: Column(
                    children: [
                      TextField(
                        onChanged: (v) => setState(() => _searchQuery = v),
                        decoration: const InputDecoration(
                          hintText: 'بحث باسم المورد أو الكود أو الهاتف...',
                          prefixIcon: Icon(Icons.search),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'عدد الموردين: ${filtered.length}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          Text(
                            'إجمالي الأرصدة الافتتاحية: ${Formatters.formatCurrency(totalOpening)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // قائمة الموردين
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(child: Text('لا يوجد موردون مطابقون للبحث'))
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final s = filtered[index];
                            final hasOpening = s.openingBalance > 0;

                            return Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: hasOpening
                                      ? AppTheme.primary.withValues(alpha: 0.1)
                                      : Colors.grey.withValues(alpha: 0.1),
                                  child: Icon(
                                    Icons.store_outlined,
                                    color: hasOpening ? AppTheme.primary : Colors.grey,
                                  ),
                                ),
                                title: Text(
                                  s.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text('الكود: ${s.code} ${s.phone != null ? "• ${s.phone}" : ""}'),
                                    if (s.openingBalanceDate != null)
                                      Text(
                                        'التاريخ: ${s.openingBalanceDate} ${s.openingBalanceNotes != null ? "(${s.openingBalanceNotes})" : ""}',
                                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                      ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          Formatters.formatCurrency(s.openingBalance),
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: hasOpening ? AppTheme.primary : AppTheme.textSecondary,
                                          ),
                                        ),
                                        const Text(
                                          'رصيد افتتاحي',
                                          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 20, color: AppTheme.primary),
                                      onPressed: () => _showEditOpeningBalanceDialog(s),
                                      tooltip: 'تعديل الرصيد الافتتاحي',
                                    ),
                                  ],
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
