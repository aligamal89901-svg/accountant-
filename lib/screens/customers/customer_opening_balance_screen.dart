import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/database/database_helper.dart';
import '../../models/customer_model.dart';

/// شاشة إدارة الأرصدة الافتتاحية للعملاء
class CustomerOpeningBalanceScreen extends StatefulWidget {
  const CustomerOpeningBalanceScreen({super.key});

  @override
  State<CustomerOpeningBalanceScreen> createState() => _CustomerOpeningBalanceScreenState();
}

class _CustomerOpeningBalanceScreenState extends State<CustomerOpeningBalanceScreen> {
  List<CustomerModel> _customers = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    setState(() => _isLoading = true);
    final customers = await DatabaseHelper.instance.getCustomers();
    if (mounted) {
      setState(() {
        _customers = customers;
        _isLoading = false;
      });
    }
  }

  void _showEditOpeningBalanceDialog(CustomerModel customer) {
    final amountController = TextEditingController(
      text: customer.openingBalance > 0 ? customer.openingBalance.toString() : '',
    );
    final notesController = TextEditingController(text: customer.openingBalanceNotes ?? '');
    String selectedDate = customer.openingBalanceDate ?? DateTime.now().toIso8601String().substring(0, 10);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.account_balance_wallet_outlined, color: AppTheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text('الرصيد الافتتاحي: ${customer.name}',
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
                    'الرصيد الافتتاحي هو المبلغ المستحق على العميل قبل بدء التسجيل بالنظام:',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: amountController,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'المبلغ المستحق الافتتاحي *',
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
                        child: const Text('تغيير'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: notesController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظات الرصيد الافتتاحي (اختياري)',
                      hintText: 'مثال: رصيد منقول من الدفتر القديم...',
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
                final amount = double.tryParse(amountController.text.trim()) ?? 0.0;
                await DatabaseHelper.instance.setCustomerOpeningBalance(
                  customerId: customer.id!,
                  amount: amount,
                  date: selectedDate,
                  notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                );
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('تم تحديث الرصيد الافتتاحي للعميل ${customer.name} بنجاح'),
                      backgroundColor: AppTheme.success,
                    ),
                  );
                  _loadCustomers();
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
    final filtered = _customers.where((c) {
      if (_searchQuery.isEmpty) return true;
      return c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          c.code.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    final double totalOpening = _customers.fold(0.0, (sum, c) => sum + c.openingBalance);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الأرصدة الافتتاحية للعملاء'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث',
            onPressed: _loadCustomers,
          ),
          const SizedBox(width: 8),
        ],
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
                        // ملخص إجمالي الأرصدة الافتتاحية
                        Container(
                          margin: const EdgeInsets.all(16),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                                  Icon(Icons.info_outline, color: AppTheme.primary, size: 20),
                                  SizedBox(width: 8),
                                  Text('إجمالي الأرصدة الافتتاحية المسجلة:', style: TextStyle(fontWeight: FontWeight.bold)),
                                ],
                              ),
                              Text(
                                Formatters.formatCurrency(totalOpening),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primary),
                              ),
                            ],
                          ),
                        ),

                        // شريط البحث
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: TextField(
                            decoration: const InputDecoration(
                              hintText: 'ابحث باسم العميل أو الكود...',
                              prefixIcon: Icon(Icons.search),
                            ),
                            onChanged: (val) => setState(() => _searchQuery = val.trim()),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // قائمة العملاء
                        Expanded(
                          child: filtered.isEmpty
                              ? const Center(
                                  child: Text('لا يوجد عملاء مطابقين للبحث', style: TextStyle(color: AppTheme.textSecondary)),
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                  itemCount: filtered.length,
                                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                                  itemBuilder: (ctx, i) {
                                    final customer = filtered[i];
                                    final hasOpening = customer.openingBalance > 0;

                                    return Container(
                                      decoration: AppTheme.cardDecoration(),
                                      child: ListTile(
                                        title: Text(customer.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                        subtitle: Text(
                                          hasOpening
                                              ? 'تاريخ: ${customer.openingBalanceDate ?? "غير محدد"}${customer.openingBalanceNotes != null ? " | ${customer.openingBalanceNotes}" : ""}'
                                              : 'لم يتم تسجيل رصيد افتتاحي',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: hasOpening ? AppTheme.textSecondary : Colors.grey,
                                          ),
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              Formatters.formatCurrency(customer.openingBalance),
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: hasOpening ? AppTheme.primary : AppTheme.neutral,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            IconButton(
                                              icon: const Icon(Icons.edit_outlined, color: AppTheme.primary, size: 20),
                                              tooltip: 'تعديل الرصيد الافتتاحي',
                                              onPressed: () => _showEditOpeningBalanceDialog(customer),
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
                  ),
                );
              },
            ),
    );
  }
}
