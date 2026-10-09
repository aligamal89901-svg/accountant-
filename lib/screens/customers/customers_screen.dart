import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/database/database_helper.dart';
import '../../models/customer_model.dart';
import '../sales/invoice_receipt_dialog.dart';
import 'customer_debts_screen.dart';

/// شاشة العملاء وذمم الحسابات وسداد الدفعات (حسب البند 6 و 7 من المواصفات)
class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<CustomerModel> _customers = [];
  bool _isLoading = true;
  bool _showDebtorsOnly = false;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    setState(() => _isLoading = true);
    final customers = await DatabaseHelper.instance.getCustomers(query: _searchController.text);
    if (mounted) {
      setState(() {
        _customers = customers;
        _isLoading = false;
      });
    }
  }

  List<CustomerModel> get _displayedCustomers {
    if (_showDebtorsOnly) {
      return _customers.where((c) => c.hasDebt).toList();
    }
    return _customers;
  }

  double get _totalDebt => _customers.fold(0.0, (sum, c) => sum + c.currentBalance);
  int get _debtorsCount => _customers.where((c) => c.hasDebt).length;

  void _showAddEditCustomerDialog([CustomerModel? existingCustomer]) async {
    final nextCode = existingCustomer?.code ?? await DatabaseHelper.instance.generateNextCustomerCode();
    final nameController = TextEditingController(text: existingCustomer?.name ?? '');
    final phoneController = TextEditingController(text: existingCustomer?.phone ?? '');
    final addressController = TextEditingController(text: existingCustomer?.address ?? '');
    final creditLimitController = TextEditingController(
        text: existingCustomer?.creditLimit != null ? existingCustomer!.creditLimit.toString() : '');
    final dueDaysController = TextEditingController(
        text: existingCustomer?.dueDays != null ? existingCustomer!.dueDays.toString() : '');
    int priceTier = existingCustomer?.defaultPriceTier ?? 1;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existingCustomer == null ? 'إضافة عميل جديد' : 'تعديل بيانات العميل'),
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
                        const Text('رمز العميل:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(nextCode, style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'اسم العميل *', hintText: 'مثال: شركة النور أو أحمد علي'),
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
                    decoration: const InputDecoration(labelText: 'العنوان / المدينة', hintText: 'الرياض - الملز'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    initialValue: priceTier,
                    decoration: const InputDecoration(labelText: 'سعر البيع الافتراضي للعميل'),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('سعر 1 (قطاعي/افتراضي)')),
                      DropdownMenuItem(value: 2, child: Text('سعر 2 (جملة)')),
                      DropdownMenuItem(value: 3, child: Text('سعر 3 (خاص)')),
                    ],
                    onChanged: (v) => setDialogState(() => priceTier = v ?? 1),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: creditLimitController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'سقف الدين (اختياري)'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: dueDaysController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'أيام الاستحقاق'),
                        ),
                      ),
                    ],
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
                    const SnackBar(content: Text('يرجى إدخال اسم العميل')),
                  );
                  return;
                }

                final customer = CustomerModel(
                  id: existingCustomer?.id,
                  code: nextCode,
                  name: name,
                  phone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
                  address: addressController.text.trim().isEmpty ? null : addressController.text.trim(),
                  defaultPriceTier: priceTier,
                  creditLimit: double.tryParse(creditLimitController.text.trim()),
                  dueDays: int.tryParse(dueDaysController.text.trim()),
                );

                if (existingCustomer == null) {
                  await DatabaseHelper.instance.insertCustomer(customer);
                } else {
                  await DatabaseHelper.instance.updateCustomer(customer);
                }

                if (ctx.mounted) Navigator.pop(ctx);
                _loadCustomers();
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPaymentDialog(CustomerModel customer) async {
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
    final amountController = TextEditingController(text: customer.currentBalance.toStringAsFixed(2));
    final notesController = TextEditingController();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('تسجيل سداد دفعة — ${customer.name}'),
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
                      color: AppTheme.danger.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('إجمالي الرصيد المستحق:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          Formatters.formatCurrency(customer.currentBalance),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.danger, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: selectedCashBoxId,
                    decoration: const InputDecoration(labelText: 'الصندوق المستلم للدفعة *'),
                    items: cashBoxes
                        .map((b) => DropdownMenuItem(value: b.id, child: Text('${b.name} (${b.type})')))
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
                    decoration: const InputDecoration(labelText: 'ملاحظات السند / رقم الإيصال (اختياري)'),
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
                    const SnackBar(content: Text('يرجى إدخال مبلغ سداد صحيح أكبر من الصفر')),
                  );
                  return;
                }

                await DatabaseHelper.instance.recordCustomerPayment(
                  customerId: customer.id!,
                  amount: amount,
                  cashBoxId: selectedCashBoxId,
                  notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                );

                if (ctx.mounted) Navigator.pop(ctx);
                _loadCustomers();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('تم تسجيل سداد ${Formatters.formatCurrency(amount)} بنجاح وتحديث الصندوق'),
                      backgroundColor: AppTheme.success,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
              child: const Text('تأكيد السداد والتحصيل'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomerDetailsDialog(CustomerModel customer) async {
    final invoices = await DatabaseHelper.instance.getCustomerInvoices(customer.id!);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('تفاصيل العميل — ${customer.name}'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(customer.code, style: const TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.bold)),
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
                // بطاقة بيانات العميل
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('الهاتف: ${customer.phone ?? "غير مسجل"}'),
                        const SizedBox(height: 4),
                        Text('العنوان: ${customer.address ?? "غير مسجل"}'),
                        const SizedBox(height: 4),
                        Text('فئة السعر: سعر ${customer.defaultPriceTier}'),
                        if (customer.creditLimit != null) ...[
                          const SizedBox(height: 4),
                          Text('سقف الدين: ${Formatters.formatCurrency(customer.creditLimit!)}'),
                        ],
                        const Divider(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('الرصيد المستحق الحالي:', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(
                              Formatters.formatCurrency(customer.currentBalance),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: customer.hasDebt ? AppTheme.danger : AppTheme.success,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // قائمة فواتير العميل
                Text(
                  'فواتير العميل (${invoices.length} فاتورة):',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 6),
                invoices.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('لا توجد فواتير سابقة لهذا العميل'),
                      )
                    : ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 250),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: invoices.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final inv = invoices[index];
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
                                    inv.remaining > 0 ? 'متبقي: ${Formatters.formatCurrency(inv.remaining)}' : 'خالص',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      color: inv.remaining > 0 ? AppTheme.danger : AppTheme.success,
                                    ),
                                  ),
                                  const Text('عرض الفاتورة >', style: TextStyle(fontSize: 10, color: AppTheme.primary)),
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
          if (customer.hasDebt)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _showPaymentDialog(customer);
              },
              icon: const Icon(Icons.payment),
              label: const Text('تسجيل سداد دفعة'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
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
            // بطاقة ملخص الذمم والعملاء
            Container(
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        const Text('إجمالي العملاء', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(
                          '${_customers.length}',
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  Container(height: 30, width: 1, color: Colors.white24),
                  Expanded(
                    child: Column(
                      children: [
                        const Text('العملاء المدينون', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(
                          '$_debtorsCount',
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  Container(height: 30, width: 1, color: Colors.white24),
                  Expanded(
                    child: Column(
                      children: [
                        const Text('الذمم المستحقة', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(
                          Formatters.formatCurrency(_totalDebt),
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
            // شريط الفلترة والأزرار المتجاوب
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
                          hintText: 'بحث باسم العميل، الهاتف، أو الرمز...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    _loadCustomers();
                                  },
                                )
                              : null,
                        ),
                        onChanged: (_) => _loadCustomers(),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          FilterChip(
                            label: Text('المدينون فقط ($_debtorsCount)'),
                            selected: _showDebtorsOnly,
                            onSelected: (val) => setState(() => _showDebtorsOnly = val),
                            selectedColor: AppTheme.danger.withValues(alpha: 0.2),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const CustomerDebtsScreen()),
                            ).then((_) => _loadCustomers()),
                            icon: const Icon(Icons.account_balance_wallet_outlined, size: 16, color: AppTheme.danger),
                            label: const Text('كشف الذمم'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.danger,
                              minimumSize: const Size(0, 40),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _showAddEditCustomerDialog(),
                            icon: const Icon(Icons.person_add_alt_1_outlined, size: 16),
                            label: const Text('إضافة عميل'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
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
                            hintText: 'بحث باسم العميل، الهاتف، أو الرمز...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      _loadCustomers();
                                    },
                                  )
                                : null,
                          ),
                          onChanged: (_) => _loadCustomers(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: Text('الذمم المستحقة ($_debtorsCount)'),
                        selected: _showDebtorsOnly,
                        onSelected: (val) => setState(() => _showDebtorsOnly = val),
                        selectedColor: AppTheme.danger.withValues(alpha: 0.2),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CustomerDebtsScreen()),
                        ).then((_) => _loadCustomers()),
                        icon: const Icon(Icons.account_balance_wallet_outlined, color: AppTheme.danger),
                        label: const Text('شاشة الذمم المستقلة'),
                        style: OutlinedButton.styleFrom(foregroundColor: AppTheme.danger),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => _showAddEditCustomerDialog(),
                        icon: const Icon(Icons.person_add_alt_1_outlined),
                        label: const Text('إضافة عميل'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                      ),
                    ],
                  );
                }
              },
            ),
            const SizedBox(height: 12),
            // قائمة العملاء
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _displayedCustomers.isEmpty
                      ? Center(
                          child: Text(
                            _showDebtorsOnly
                                ? 'لا توجد ذمم مستحقة على أي عميل حالياً'
                                : 'لا يوجد عملاء مسجلون حالياً',
                          ),
                        )
                      : ListView.separated(
                          itemCount: _displayedCustomers.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final c = _displayedCustomers[index];
                            return Card(
                              child: ListTile(
                                onTap: () => _showCustomerDetailsDialog(c),
                                leading: CircleAvatar(
                                  backgroundColor: c.hasDebt
                                      ? AppTheme.danger.withValues(alpha: 0.1)
                                      : AppTheme.primary.withValues(alpha: 0.1),
                                  child: Icon(
                                    Icons.person,
                                    color: c.hasDebt ? AppTheme.danger : AppTheme.primary,
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.surfaceVariant,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(c.code, style: const TextStyle(fontSize: 11)),
                                    ),
                                  ],
                                ),
                                subtitle: Text(
                                  c.phone != null ? 'هاتف: ${c.phone}' : 'العنوان: ${c.address ?? "غير محدد"}',
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          Formatters.formatCurrency(c.currentBalance),
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: c.hasDebt ? AppTheme.danger : AppTheme.success,
                                          ),
                                        ),
                                        Text(
                                          c.hasDebt ? 'مستحق عليه' : 'خالص',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: c.hasDebt ? AppTheme.danger : AppTheme.success,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (c.hasDebt) ...[
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.payment, color: AppTheme.success),
                                        tooltip: 'تسجيل سداد دفعة',
                                        onPressed: () => _showPaymentDialog(c),
                                      ),
                                    ],
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 18),
                                      tooltip: 'تعديل البيانات',
                                      onPressed: () => _showAddEditCustomerDialog(c),
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
