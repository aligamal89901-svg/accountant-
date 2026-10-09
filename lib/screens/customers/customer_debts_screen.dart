import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/formatters.dart';
import '../../core/services/pdf_invoice_service.dart';
import '../../data/database/database_helper.dart';
import '../../models/customer_model.dart';
import '../../models/cash_box_model.dart';
import '../sales/invoice_receipt_dialog.dart';

/// شاشة منفصلة لمتابعة ذمم العملاء وسندات القبض (حسب البند 7 من المواصفات)
class CustomerDebtsScreen extends StatefulWidget {
  const CustomerDebtsScreen({super.key});

  @override
  State<CustomerDebtsScreen> createState() => _CustomerDebtsScreenState();
}

class _CustomerDebtsScreenState extends State<CustomerDebtsScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<CustomerModel> _debtors = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDebtors();
  }

  Future<void> _loadDebtors() async {
    setState(() => _isLoading = true);
    final allCustomers = await DatabaseHelper.instance.getCustomers(query: _searchController.text);
    if (mounted) {
      setState(() {
        _debtors = allCustomers.where((c) => c.hasDebt).toList();
        _isLoading = false;
      });
    }
  }

  double get _totalDebts => _debtors.fold(0.0, (sum, c) => sum + c.currentBalance);

  void _showCustomerDetailAndPayment(CustomerModel customer) async {
    final invoices = await DatabaseHelper.instance.getCustomerInvoices(customer.id!);
    final unpaidInvoices = invoices.where((i) => i.hasRemaining).toList();
    final cashBoxes = await DatabaseHelper.instance.getCashBoxes();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ترويسة تفاصيل العميل والذمة
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(customer.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text('رمز العميل: ${customer.code} | الهاتف: ${customer.phone ?? "غير محدد"}',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      const Text('إجمالي الذمة المستحقة', style: TextStyle(color: AppTheme.danger, fontSize: 11)),
                      Text(
                        Formatters.formatCurrency(customer.currentBalance),
                        style: const TextStyle(color: AppTheme.danger, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // أزرار العمليات: سند قبض + كشف حساب تفصيلي
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showPaymentDialog(customer, cashBoxes),
                    icon: const Icon(Icons.payments_outlined),
                    label: const Text('تسجيل سند قبض'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.success,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showCustomerStatementDialog(customer),
                    icon: const Icon(Icons.receipt_long_outlined, color: AppTheme.primary),
                    label: const Text('كشف حساب تفصيلي'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            const Text('الفواتير الآجلة غير المسددة بالكامل:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primary)),
            const SizedBox(height: 8),

            Expanded(
              child: unpaidInvoices.isEmpty
                  ? const Center(child: Text('لا توجد فواتير آجلة متبقية'))
                  : ListView.separated(
                      itemCount: unpaidInvoices.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final inv = unpaidInvoices[index];
                        return Card(
                          elevation: 0.5,
                          child: ListTile(
                            onTap: () => InvoiceReceiptDialog.show(context, inv),
                            title: Text('فاتورة رقم: ${inv.invoiceNumber}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('التاريخ: ${Formatters.formatDateTime(DateTime.tryParse(inv.date) ?? DateTime.now())}'),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('المتبقي: ${Formatters.formatCurrency(inv.remaining)}',
                                    style: const TextStyle(color: AppTheme.danger, fontWeight: FontWeight.bold, fontSize: 13)),
                                Text('الإجمالي: ${Formatters.formatCurrency(inv.total)}',
                                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
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

  void _showCustomerStatementDialog(CustomerModel customer) async {
    final statement = await DatabaseHelper.instance.getCustomerAccountStatement(customer.id!);
    final shopSettings = {
      'shopName': await DatabaseHelper.instance.getSetting(AppConstants.keyShopName) ?? AppConstants.defaultShopName,
      'shopPhone': await DatabaseHelper.instance.getSetting(AppConstants.keyShopPhone) ?? '',
      'shopAddress': await DatabaseHelper.instance.getSetting(AppConstants.keyShopAddress) ?? '',
      'shopTaxNumber': await DatabaseHelper.instance.getSetting(AppConstants.keyShopTaxNumber) ?? '',
    };

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text('كشف حساب: ${customer.name}', overflow: TextOverflow.ellipsis),
            ),
            IconButton(
              icon: const Icon(Icons.picture_as_pdf, color: AppTheme.danger),
              tooltip: 'تصدير ومشاركة PDF',
              onPressed: () {
                PdfInvoiceService.shareAccountStatementPdf(
                  partyType: 'العميل',
                  partyName: customer.name,
                  partyCode: customer.code,
                  statementEntries: statement,
                  finalBalance: customer.currentBalance,
                  shopSettings: shopSettings,
                );
              },
            ),
          ],
        ),
        content: SizedBox(
          width: 550,
          height: 400,
          child: statement.isEmpty
              ? const Center(child: Text('لا توجد حركات مسجلة لهذا العميل حتى الآن'))
              : ListView.separated(
                  itemCount: statement.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (subCtx, i) {
                    final e = statement[i];
                    final debit = (e['debit'] as num).toDouble();
                    final credit = (e['credit'] as num).toDouble();
                    final bal = (e['balance'] as num).toDouble();
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${e['type']} (${e['ref']})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Text(
                            Formatters.formatCurrency(bal),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: bal > 0 ? AppTheme.danger : AppTheme.success,
                            ),
                          ),
                        ],
                      ),
                      subtitle: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('التاريخ: ${(e['date'] as String).split("T").first}', style: const TextStyle(fontSize: 11)),
                          Text('مدين: ${Formatters.formatCurrency(debit)} | دائن: ${Formatters.formatCurrency(credit)}', style: const TextStyle(fontSize: 11)),
                        ],
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
        ],
      ),
    );
  }

  void _showPaymentDialog(CustomerModel customer, List<CashBoxModel> cashBoxes) {
    if (cashBoxes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد صندوق مهيأ في النظام لتحصيل المبلغ')),
      );
      return;
    }

    final amountController = TextEditingController(text: customer.currentBalance.toStringAsFixed(2));
    final notesController = TextEditingController();
    int selectedBoxId = cashBoxes.first.id!;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.receipt_long, color: AppTheme.success),
              const SizedBox(width: 8),
              Text('سند قبض - ${customer.name}'),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: selectedBoxId,
                    decoration: const InputDecoration(labelText: 'الصندوق المستلم *'),
                    items: cashBoxes.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
                    onChanged: (v) => setDialogState(() => selectedBoxId = v!),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'المبلغ المحصل *', suffixText: 'ر.س'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(labelText: 'ملاحظات / بيان السند (اختياري)'),
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
                    const SnackBar(content: Text('يرجى إدخال مبلغ تحصيل صحيح')),
                  );
                  return;
                }

                await DatabaseHelper.instance.recordCustomerPayment(
                  customerId: customer.id!,
                  amount: amount,
                  cashBoxId: selectedBoxId,
                  notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                );

                if (ctx.mounted) Navigator.pop(ctx); // إغلاق نافذة الدفع
                if (mounted) Navigator.pop(context); // إغلاق الـ BottomSheet
                _loadDebtors();

                // عرض إشعار وخيار طباعة سند القبض PDF
                final selectedBox = cashBoxes.firstWhere((b) => b.id == selectedBoxId);
                final shopSettings = {
                  'shopName': await DatabaseHelper.instance.getSetting(AppConstants.keyShopName) ?? AppConstants.defaultShopName,
                  'shopPhone': await DatabaseHelper.instance.getSetting(AppConstants.keyShopPhone) ?? '',
                  'shopAddress': await DatabaseHelper.instance.getSetting(AppConstants.keyShopAddress) ?? '',
                  'shopTaxNumber': await DatabaseHelper.instance.getSetting(AppConstants.keyShopTaxNumber) ?? '',
                };

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('تم تسجيل سند القبض وتسوية الذمة بنجاح!'),
                      backgroundColor: AppTheme.success,
                      action: SnackBarAction(
                        label: 'مشاركة السند PDF',
                        textColor: Colors.white,
                        onPressed: () {
                          PdfInvoiceService.sharePaymentReceiptPdf(
                            receiptType: 'سند قبض',
                            receiptNumber: 'REC-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
                            partyName: customer.name,
                            amount: amount,
                            date: DateTime.now().toIso8601String(),
                            cashBoxName: selectedBox.name,
                            notes: notesController.text.trim(),
                            shopSettings: shopSettings,
                          );
                        },
                      ),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
              child: const Text('تأكيد التحصيل'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ذمم ومستحقات العملاء', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // بطاقة ملخص الذمم
            Card(
              color: AppTheme.primary,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('إجمالي الديون المستحقة على العملاء',
                              style: TextStyle(color: Colors.white70, fontSize: 13)),
                          const SizedBox(height: 6),
                          Text(
                            Formatters.formatCurrency(_totalDebts),
                            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.group_outlined, color: Colors.white, size: 24),
                          const SizedBox(height: 4),
                          Text('${_debtors.length} عميل مدين',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // حقل البحث السريع
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'ابحث عن عميل مدين بالاسم أو الرمز أو الهاتف...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _loadDebtors();
                        },
                      )
                    : null,
              ),
              onChanged: (_) => _loadDebtors(),
            ),
            const SizedBox(height: 14),

            // قائمة العملاء المدينين
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _debtors.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_outline, size: 64, color: AppTheme.success),
                              SizedBox(height: 12),
                              Text('رائع! لا توجد ذمم أو ديون متأخرة على العملاء',
                                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: _debtors.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final c = _debtors[index];
                            return Card(
                              child: ListTile(
                                onTap: () => _showCustomerDetailAndPayment(c),
                                leading: CircleAvatar(
                                  backgroundColor: AppTheme.danger.withValues(alpha: 0.1),
                                  child: const Icon(Icons.person_outline, color: AppTheme.danger),
                                ),
                                title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                subtitle: Text('الرمز: ${c.code} | الهاتف: ${c.phone ?? "غير مسجل"}'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          Formatters.formatCurrency(c.currentBalance),
                                          style: const TextStyle(
                                            color: AppTheme.danger,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const Text('مبلغ متبقي', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                                      ],
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.chevron_left, color: AppTheme.textMuted),
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
