import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/database/database_helper.dart';
import '../../models/supplier_model.dart';
import '../../models/invoice_model.dart';
import '../sales/invoice_receipt_dialog.dart';
import 'supplier_debts_screen.dart';

/// شاشة الموردين وإدارة المستحقات وسداد الدفعات (حسب البند 8 من المواصفات)
class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<SupplierModel> _suppliers = [];
  bool _isLoading = true;
  bool _showPayablesOnly = false;

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
  }

  Future<void> _loadSuppliers() async {
    setState(() => _isLoading = true);
    final suppliers = await DatabaseHelper.instance.getSuppliers(query: _searchController.text);
    if (mounted) {
      setState(() {
        _suppliers = suppliers;
        _isLoading = false;
      });
    }
  }

  List<SupplierModel> get _displayedSuppliers {
    if (_showPayablesOnly) {
      return _suppliers.where((s) => s.hasPayables).toList();
    }
    return _suppliers;
  }

  double get _totalPayables => _suppliers.fold(0.0, (sum, s) => sum + s.currentBalance);
  int get _payablesCount => _suppliers.where((s) => s.hasPayables).length;

  void _showAddEditSupplierDialog([SupplierModel? existingSupplier]) async {
    final nextCode = existingSupplier?.code ?? await DatabaseHelper.instance.generateNextSupplierCode();
    final nameController = TextEditingController(text: existingSupplier?.name ?? '');
    final phoneController = TextEditingController(text: existingSupplier?.phone ?? '');
    final addressController = TextEditingController(text: existingSupplier?.address ?? '');
    final taxNumberController = TextEditingController(text: existingSupplier?.taxNumber ?? '');

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existingSupplier == null ? 'إضافة مورد جديد' : 'تعديل بيانات المورد'),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('رمز المورد:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(nextCode, style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'اسم المورد / الشركة *', hintText: 'مثال: شركة التوزيع الكبرى'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'رقم الهاتف', hintText: '05xxxxxxxx'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(labelText: 'العنوان', hintText: 'المدينة / المنطقة'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: taxNumberController,
                  decoration: const InputDecoration(labelText: 'الرقم الضريبي (اختياري)'),
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
              final name = nameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('يرجى إدخال اسم المورد')),
                );
                return;
              }

              final supplier = SupplierModel(
                id: existingSupplier?.id,
                code: nextCode,
                name: name,
                phone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
                address: addressController.text.trim().isEmpty ? null : addressController.text.trim(),
                taxNumber: taxNumberController.text.trim().isEmpty ? null : taxNumberController.text.trim(),
              );

              if (existingSupplier == null) {
                await DatabaseHelper.instance.insertSupplier(supplier);
              } else {
                await DatabaseHelper.instance.updateSupplier(supplier);
              }

              if (ctx.mounted) Navigator.pop(ctx);
              _loadSuppliers();
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _showSupplierPaymentDialog(SupplierModel supplier) async {
    final cashBoxes = await DatabaseHelper.instance.getCashBoxes();
    if (cashBoxes.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا يوجد صندوق مهيأ في النظام')),
        );
      }
      return;
    }

    int selectedCashBoxId = cashBoxes.first.id!;
    final amountController = TextEditingController(text: supplier.currentBalance.toStringAsFixed(2));
    final notesController = TextEditingController();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('سداد مستحقات مورد — ${supplier.name}'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('إجمالي المستحق للمورد:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          Formatters.formatCurrency(supplier.currentBalance),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.warning, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: selectedCashBoxId,
                    decoration: const InputDecoration(labelText: 'الصندوق المسدد منه (سند صرف) *'),
                    items: cashBoxes
                        .map((b) => DropdownMenuItem(value: b.id, child: Text('${b.name} (${Formatters.formatCurrency(b.balance)})')))
                        .toList(),
                    onChanged: (v) => setDialogState(() => selectedCashBoxId = v!),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'المبلغ المسدد *', hintText: '0.00'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(labelText: 'رقم السند / ملاحظات الصرف (اختياري)'),
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
                    const SnackBar(content: Text('يرجى إدخال مبلغ صحيح أكبر من الصفر')),
                  );
                  return;
                }

                await DatabaseHelper.instance.recordSupplierPayment(
                  supplierId: supplier.id!,
                  amount: amount,
                  cashBoxId: selectedCashBoxId,
                  notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                );

                if (ctx.mounted) Navigator.pop(ctx);
                _loadSuppliers();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('تم تسجيل سند صرف ${Formatters.formatCurrency(amount)} للمورد بنجاح'),
                      backgroundColor: AppTheme.success,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
              child: const Text('تأكيد سند الصرف'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSupplierDetailsDialog(SupplierModel supplier) async {
    final db = await DatabaseHelper.instance.database;
    final res = await db.query(
      'invoices',
      where: 'supplier_id = ? AND type = "purchase"',
      orderBy: 'id DESC',
    );
    final purchases = res.map((e) => InvoiceModel.fromMap(e)).toList();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('كشف حساب المورد — ${supplier.name}'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(supplier.code, style: const TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // بطاقة بيانات المورد
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('الهاتف: ${supplier.phone ?? "غير مسجل"}'),
                        const SizedBox(height: 4),
                        Text('العنوان: ${supplier.address ?? "غير مسجل"}'),
                        if (supplier.taxNumber != null) ...[
                          const SizedBox(height: 4),
                          Text('الرقم الضريبي: ${supplier.taxNumber}'),
                        ],
                        const Divider(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('إجمالي المستحق للمورد:', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(
                              Formatters.formatCurrency(supplier.currentBalance),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: supplier.hasPayables ? AppTheme.warning : AppTheme.success,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'فواتير المشتريات (${purchases.length} فاتورة):',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 6),
                purchases.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('لا توجد فواتير مشتريات سابقة مسجلة لهذا المورد'),
                      )
                    : ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 250),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: purchases.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final inv = purchases[index];
                            return ListTile(
                              dense: true,
                              onTap: () => InvoiceReceiptDialog.show(context, inv),
                              title: Text(inv.invoiceNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                '${Formatters.formatDate(DateTime.parse(inv.date))} | إجمالي: ${Formatters.formatCurrency(inv.total)}',
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    inv.remaining > 0 ? 'متبقي: ${Formatters.formatCurrency(inv.remaining)}' : 'مسدد بالكامل',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      color: inv.remaining > 0 ? AppTheme.warning : AppTheme.success,
                                    ),
                                  ),
                                  const Text('عرض التفاصيل >', style: TextStyle(fontSize: 10, color: AppTheme.primary)),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
          if (supplier.hasPayables)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _showSupplierPaymentDialog(supplier);
              },
              icon: const Icon(Icons.payment),
              label: const Text('سداد دفعة للمورد'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            ),
        ],
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
            // بطاقة ملخص الموردين
            Container(
              decoration: BoxDecoration(
                color: AppTheme.primaryDark,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        const Text('إجمالي الموردين', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(
                          '${_suppliers.length}',
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  Container(height: 30, width: 1, color: Colors.white24),
                  Expanded(
                    child: Column(
                      children: [
                        const Text('الموردون الدائنون', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(
                          '$_payablesCount',
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  Container(height: 30, width: 1, color: Colors.white24),
                  Expanded(
                    child: Column(
                      children: [
                        const Text('إجمالي المستحقات', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(
                          Formatters.formatCurrency(_totalPayables),
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // شريط البحث والفلترة المتجاوب
            LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 650;

                if (isMobile) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'بحث باسم المورد، الهاتف، أو الرمز...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    _loadSuppliers();
                                  },
                                )
                              : null,
                        ),
                        onChanged: (_) => _loadSuppliers(),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          FilterChip(
                            label: Text('المستحقات فقط ($_payablesCount)'),
                            selected: _showPayablesOnly,
                            onSelected: (val) => setState(() => _showPayablesOnly = val),
                            selectedColor: AppTheme.warning.withValues(alpha: 0.2),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const SupplierDebtsScreen()),
                            ).then((_) => _loadSuppliers()),
                            icon: const Icon(Icons.outbox_outlined, size: 16, color: AppTheme.secondary),
                            label: const Text('كشف المستحقات'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.secondary,
                              minimumSize: const Size(0, 40),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _showAddEditSupplierDialog(),
                            icon: const Icon(Icons.add_business_outlined, size: 16),
                            label: const Text('إضافة مورد'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.secondary,
                              minimumSize: const Size(0, 40),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                } else {
                  return Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'بحث باسم المورد، الهاتف، أو الرمز...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      _loadSuppliers();
                                    },
                                  )
                                : null,
                          ),
                          onChanged: (_) => _loadSuppliers(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: Text('المستحقات فقط ($_payablesCount)'),
                        selected: _showPayablesOnly,
                        onSelected: (val) => setState(() => _showPayablesOnly = val),
                        selectedColor: AppTheme.warning.withValues(alpha: 0.2),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SupplierDebtsScreen()),
                        ).then((_) => _loadSuppliers()),
                        icon: const Icon(Icons.outbox_outlined, color: AppTheme.secondary),
                        label: const Text('شاشة المستحقات المستقلة'),
                        style: OutlinedButton.styleFrom(foregroundColor: AppTheme.secondary),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => _showAddEditSupplierDialog(),
                        icon: const Icon(Icons.add_business_outlined),
                        label: const Text('إضافة مورد'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondary),
                      ),
                    ],
                  );
                }
              },
            ),
            const SizedBox(height: 12),
            // قائمة الموردين
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _displayedSuppliers.isEmpty
                      ? Center(
                          child: Text(
                            _showPayablesOnly
                                ? 'لا توجد مستحقات معلقة لأي مورد حالياً'
                                : 'لا يوجد موردون مسجلون حالياً',
                          ),
                        )
                      : ListView.separated(
                          itemCount: _displayedSuppliers.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final s = _displayedSuppliers[index];
                            return Card(
                              child: ListTile(
                                onTap: () => _showSupplierDetailsDialog(s),
                                leading: const CircleAvatar(
                                  backgroundColor: AppTheme.surfaceVariant,
                                  child: Icon(Icons.local_shipping, color: AppTheme.primary),
                                ),
                                title: Row(
                                  children: [
                                    Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.surfaceVariant,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(s.code, style: const TextStyle(fontSize: 11)),
                                    ),
                                  ],
                                ),
                                subtitle: Text(
                                  s.phone != null ? 'هاتف: ${s.phone}' : 'العنوان: ${s.address ?? "غير محدد"}',
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          Formatters.formatCurrency(s.currentBalance),
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: s.hasPayables ? AppTheme.warning : AppTheme.textPrimary,
                                          ),
                                        ),
                                        Text(
                                          s.hasPayables ? 'مستحق له' : 'خالص',
                                          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                        ),
                                      ],
                                    ),
                                    if (s.hasPayables) ...[
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.payment, color: AppTheme.danger),
                                        tooltip: 'سداد دفعة للمورد',
                                        onPressed: () => _showSupplierPaymentDialog(s),
                                      ),
                                    ],
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 18),
                                      tooltip: 'تعديل البيانات',
                                      onPressed: () => _showAddEditSupplierDialog(s),
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
  }
}
