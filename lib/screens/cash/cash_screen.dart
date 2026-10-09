import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/database/database_helper.dart';
import '../../models/cash_box_model.dart';
import '../../models/cash_transaction_model.dart';

/// شاشة الصندوق وإدارة الحركات المالية الحقيقية
class CashScreen extends StatefulWidget {
  const CashScreen({super.key});

  @override
  State<CashScreen> createState() => _CashScreenState();
}

class _CashScreenState extends State<CashScreen> {
  List<CashBoxModel> _cashBoxes = [];
  List<CashTransactionModel> _transactions = [];
  int? _selectedCashBoxId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCashData();
  }

  Future<void> _loadCashData() async {
    setState(() => _isLoading = true);
    final boxes = await DatabaseHelper.instance.getCashBoxes();
    final transactions = await DatabaseHelper.instance.getCashTransactions(cashBoxId: _selectedCashBoxId);

    if (mounted) {
      setState(() {
        _cashBoxes = boxes;
        _transactions = transactions;
        _isLoading = false;
      });
    }
  }

  double get _totalBalance => _cashBoxes.fold(0.0, (sum, b) => sum + b.balance);

  void _showAddTransactionDialog(String type) {
    if (_cashBoxes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد صندوق مهيأ في النظام')),
      );
      return;
    }

    final amountController = TextEditingController();
    final descController = TextEditingController();
    int selectedBoxId = _selectedCashBoxId ?? _cashBoxes.first.id!;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(type == 'إيداع' ? 'إيداع مبلغ في الصندوق' : 'صرف مبلغ من الصندوق'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: selectedBoxId,
                    decoration: const InputDecoration(labelText: 'الصندوق'),
                    items: _cashBoxes
                        .map((b) => DropdownMenuItem(value: b.id, child: Text('${b.name} (${b.type})')))
                        .toList(),
                    onChanged: (v) => setDialogState(() => selectedBoxId = v!),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'المبلغ *', hintText: '0.00'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    decoration: InputDecoration(
                      labelText: 'البيان / السبب *',
                      hintText: type == 'إيداع' ? 'مثال: رصيد افتتاحي، إيداع يدوي' : 'مثال: مصاريف نثرية، إيجار، فواتير',
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
                final amount = double.tryParse(amountController.text.trim());
                final desc = descController.text.trim();
                if (amount == null || amount <= 0 || desc.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('يرجى إدخال مبلغ صحيح وبيان الحركة')),
                  );
                  return;
                }

                await DatabaseHelper.instance.recordCashTransaction(
                  cashBoxId: selectedBoxId,
                  type: type,
                  amount: amount,
                  description: desc,
                  relatedAccountType: 'يدوي',
                );

                if (ctx.mounted) Navigator.pop(ctx);
                _loadCashData();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: type == 'إيداع' ? AppTheme.success : AppTheme.danger,
              ),
              child: Text(type == 'إيداع' ? 'تأكيد الإيداع' : 'تأكيد الصرف'),
            ),
          ],
        ),
      ),
    );
  }

  void _showTransferDialog() {
    if (_cashBoxes.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يلزم توفر صندوقين على الأقل لإجراء تحويل مالي')),
      );
      return;
    }

    int fromBoxId = _cashBoxes.first.id!;
    int toBoxId = _cashBoxes[1].id!;
    final amountController = TextEditingController();
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final fromBox = _cashBoxes.firstWhere((b) => b.id == fromBoxId);
          return AlertDialog(
            title: const Text('تحويل بين الصناديق / الخزائن'),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<int>(
                      initialValue: fromBoxId,
                      decoration: InputDecoration(
                        labelText: 'من الصندوق (المصدر)',
                        helperText: 'الرصيد المتاح: ${Formatters.formatCurrency(fromBox.balance)}',
                      ),
                      items: _cashBoxes
                          .map((b) => DropdownMenuItem(value: b.id, child: Text('${b.name} (${Formatters.formatCurrency(b.balance)})')))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setDialogState(() {
                            fromBoxId = v;
                            if (fromBoxId == toBoxId) {
                              toBoxId = _cashBoxes.firstWhere((b) => b.id != fromBoxId).id!;
                            }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: toBoxId,
                      decoration: const InputDecoration(labelText: 'إلى الصندوق (المستلم)'),
                      items: _cashBoxes
                          .where((b) => b.id != fromBoxId)
                          .map((b) => DropdownMenuItem(value: b.id, child: Text('${b.name} (${Formatters.formatCurrency(b.balance)})')))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setDialogState(() => toBoxId = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'مبلغ التحويل *',
                        hintText: '0.00',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      decoration: const InputDecoration(
                        labelText: 'ملاحظات / سبب التحويل',
                        hintText: 'مثال: تغذية الصندوق الفرعي من البنك',
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
                  final amount = double.tryParse(amountController.text.trim());
                  if (amount == null || amount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('يرجى إدخال مبلغ تحويل صالح')),
                    );
                    return;
                  }
                  if (amount > fromBox.balance) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('المبلغ المطلوب تحويله يتجاوز رصيد الصندوق المصدر')),
                    );
                    return;
                  }

                  final success = await DatabaseHelper.instance.transferBetweenCashBoxes(
                    fromBoxId: fromBoxId,
                    toBoxId: toBoxId,
                    amount: amount,
                    notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                  );

                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم تحويل المبلغ بنجاح')),
                      );
                      _loadCashData();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تعذر إتمام التحويل، تأكد من توفر الرصيد الكافي')),
                      );
                    }
                  }
                },
                child: const Text('تأكيد التحويل'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddCashBoxDialog() {
    final nameController = TextEditingController();
    final balanceController = TextEditingController(text: '0.0');
    String type = 'نقد';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('إضافة صندوق / حساب جديد'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'اسم الصندوق / الحساب *',
                      hintText: 'مثال: خزينة المبيعات، حساب الراجحي',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    decoration: const InputDecoration(labelText: 'النوع'),
                    items: const [
                      DropdownMenuItem(value: 'نقد', child: Text('صندوق نقدي (كاش)')),
                      DropdownMenuItem(value: 'شبكة/بطاقة', child: Text('حساب بنكي / شبكة مدفوعات')),
                      DropdownMenuItem(value: 'شيك', child: Text('محفظة شيكات')),
                    ],
                    onChanged: (v) => setDialogState(() => type = v!),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: balanceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'الرصيد الافتتاحي', hintText: '0.00'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('يرجى إدخال اسم الصندوق')),
                  );
                  return;
                }
                final initBal = double.tryParse(balanceController.text.trim()) ?? 0.0;
                final newBox = CashBoxModel(
                  name: name,
                  type: type,
                  balance: initBal,
                  isDefault: _cashBoxes.isEmpty,
                );
                final id = await DatabaseHelper.instance.insertCashBox(newBox);
                if (initBal > 0) {
                  await DatabaseHelper.instance.recordCashTransaction(
                    cashBoxId: id,
                    type: 'إيداع',
                    amount: initBal,
                    description: 'رصيد افتتاحي للصندوق',
                    relatedAccountType: 'رصيد افتتاحي',
                  );
                }
                if (ctx.mounted) Navigator.pop(ctx);
                _loadCashData();
              },
              child: const Text('حفظ الصندوق'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // بطاقة رصيد الصندوق
            Card(
              color: AppTheme.secondary,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'إجمالي السيولة المتاحة في الصناديق',
                          style: TextStyle(color: Colors.white, fontSize: 14),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${_cashBoxes.length} خزينة',
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      Formatters.formatCurrency(_totalBalance),
                      style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, cardConstraints) {
                        final isCompact = cardConstraints.maxWidth < 500;
                        if (isCompact) {
                          return Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => _showAddTransactionDialog('إيداع'),
                                      icon: const Icon(Icons.arrow_downward, color: Colors.white, size: 18),
                                      label: const Text('إيداع مبلغ'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.success,
                                        foregroundColor: Colors.white,
                                        minimumSize: const Size(0, 44),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => _showAddTransactionDialog('صرف'),
                                      icon: const Icon(Icons.arrow_upward, color: Colors.white, size: 18),
                                      label: const Text('صرف مبلغ'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.danger,
                                        foregroundColor: Colors.white,
                                        minimumSize: const Size(0, 44),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _showTransferDialog,
                                      icon: const Icon(Icons.swap_horiz, color: Colors.white, size: 18),
                                      label: const Text('تحويل داخلي'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primary,
                                        foregroundColor: Colors.white,
                                        minimumSize: const Size(0, 44),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _showAddCashBoxDialog,
                                      icon: const Icon(Icons.add_card, color: Colors.white, size: 18),
                                      label: const Text('صندوق جديد', style: TextStyle(color: Colors.white)),
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: Colors.white54),
                                        minimumSize: const Size(0, 44),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        } else {
                          return Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => _showAddTransactionDialog('إيداع'),
                                      icon: const Icon(Icons.arrow_downward, color: Colors.white),
                                      label: const Text('إيداع مبلغ'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.success,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => _showAddTransactionDialog('صرف'),
                                      icon: const Icon(Icons.arrow_upward, color: Colors.white),
                                      label: const Text('صرف مبلغ'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.danger,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _showTransferDialog,
                                      icon: const Icon(Icons.swap_horiz, color: Colors.white),
                                      label: const Text('تحويل داخلي'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primary,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _showAddCashBoxDialog,
                                  icon: const Icon(Icons.add_card, color: Colors.white),
                                  label: const Text('إضافة صندوق / حساب بنكي جديد', style: TextStyle(color: Colors.white)),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Colors.white54),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // فلاتر الصناديق
            if (_cashBoxes.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('كافة الصناديق'),
                      selected: _selectedCashBoxId == null,
                      onSelected: (selected) {
                        setState(() => _selectedCashBoxId = null);
                        _loadCashData();
                      },
                    ),
                    const SizedBox(width: 8),
                    ..._cashBoxes.map((box) {
                      return Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: FilterChip(
                          label: Text('${box.name} (${Formatters.formatCurrency(box.balance)})'),
                          selected: _selectedCashBoxId == box.id,
                          onSelected: (selected) {
                            setState(() => _selectedCashBoxId = selected ? box.id : null);
                            _loadCashData();
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            // عنوان الحركات
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'سجل الحركات المالية الأخيرة',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  '${_transactions.length} حركة',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // قائمة الحركات
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _transactions.isEmpty
                      ? const Center(child: Text('لا توجد حركات مسجلة في الصندوق بعد'))
                      : ListView.separated(
                          itemCount: _transactions.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final t = _transactions[index];
                            final isDeposit = t.isDeposit;
                            return Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isDeposit
                                      ? AppTheme.success.withValues(alpha: 0.1)
                                      : AppTheme.danger.withValues(alpha: 0.1),
                                  child: Icon(
                                    isDeposit ? Icons.arrow_downward : Icons.arrow_upward,
                                    color: isDeposit ? AppTheme.success : AppTheme.danger,
                                  ),
                                ),
                                title: Text(t.description, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text(
                                  '${t.cashBoxName ?? "الصندوق"} | ${Formatters.formatDateTime(DateTime.parse(t.date))}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: Text(
                                  '${isDeposit ? "+" : "-"} ${Formatters.formatCurrency(t.amount)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: isDeposit ? AppTheme.success : AppTheme.danger,
                                  ),
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
  }
}
