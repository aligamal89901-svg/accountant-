import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/formatters.dart';
import '../../core/services/pdf_invoice_service.dart';
import '../../data/database/database_helper.dart';
import '../../models/supplier_model.dart';
import '../../models/cash_box_model.dart';
import '../sales/invoice_receipt_dialog.dart';

/// شاشة منفصلة لمتابعة ذمم ومستحقات الموردين وسندات الصرف (حسب البند 8 من المواصفات)
class SupplierDebtsScreen extends StatefulWidget {
  const SupplierDebtsScreen({super.key});

  @override
  State<SupplierDebtsScreen> createState() => _SupplierDebtsScreenState();
}

class _SupplierDebtsScreenState extends State<SupplierDebtsScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<SupplierModel> _creditors = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCreditors();
  }

  Future<void> _loadCreditors() async {
    setState(() => _isLoading = true);
    final allSuppliers = await DatabaseHelper.instance.getSuppliers(query: _searchController.text);
    if (mounted) {
      setState(() {
        _creditors = allSuppliers.where((s) => s.hasPayables).toList();
        _isLoading = false;
      });
    }
  }

  double get _totalPayables => _creditors.fold(0.0, (sum, s) => sum + s.currentBalance);

  void _showSupplierDetailAndPayment(SupplierModel supplier) async {
    final invoices = await DatabaseHelper.instance.getInvoices(type: 'purchase');
    final supplierInvoices = invoices.where((i) => i.supplierId == supplier.id && i.hasRemaining).toList();
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
            // ترويسة تفاصيل المورد والمستحقات
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(supplier.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text('رمز المورد: ${supplier.code} | الهاتف: ${supplier.phone ?? "غير مسجل"}',
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
                      const Text('إجمالي المستحق للمورد', style: TextStyle(color: AppTheme.danger, fontSize: 11)),
                      Text(
                        Formatters.formatCurrency(supplier.currentBalance),
                        style: const TextStyle(color: AppTheme.danger, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // أزرار العمليات: سند صرف + كشف حساب تفصيلي
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showPaymentDialog(supplier, cashBoxes),
                    icon: const Icon(Icons.outbox_outlined),
                    label: const Text('تسجيل سند صرف'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.secondary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showSupplierStatementDialog(supplier),
                    icon: const Icon(Icons.receipt_long_outlined, color: AppTheme.secondary),
                    label: const Text('كشف حساب تفصيلي'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            const Text('فواتير المشتريات الآجلة المتبقية للمورد:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primary)),
            const SizedBox(height: 8),

            Expanded(
              child: supplierInvoices.isEmpty
                  ? const Center(child: Text('لا توجد فواتير مشتريات آجلة متبقية لهذا المورد'))
                  : ListView.separated(
                      itemCount: supplierInvoices.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final inv = supplierInvoices[index];
                        return Card(
                          elevation: 0.5,
                          child: ListTile(
                            onTap: () => InvoiceReceiptDialog.show(context, inv),
                            title: Text('فاتورة مشتريات رقم: ${inv.invoiceNumber}',
                                style: const TextStyle(fontWeight: FontWeight.bold)),
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

  void _showSupplierStatementDialog(SupplierModel supplier) async {
    final statement = await DatabaseHelper.instance.getSupplierAccountStatement(supplier.id!);
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
              child: Text('كشف حساب المورد: ${supplier.name}', overflow: TextOverflow.ellipsis),
            ),
            IconButton(
              icon: const Icon(Icons.picture_as_pdf, color: AppTheme.danger),
              tooltip: 'تصدير ومشاركة PDF',
              onPressed: () {
                PdfInvoiceService.shareAccountStatementPdf(
                  partyType: 'المورد',
                  partyName: supplier.name,
                  partyCode: supplier.code,
                  statementEntries: statement,
                  finalBalance: supplier.currentBalance,
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
              ? const Center(child: Text('لا توجد حركات مسجلة لهذا المورد حتى الآن'))
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
                          Text('سداد (مدين): ${Formatters.formatCurrency(debit)} | مشتريات (دائن): ${Formatters.formatCurrency(credit)}', style: const TextStyle(fontSize: 11)),
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

  void _showPaymentDialog(SupplierModel supplier, List<CashBoxModel> cashBoxes) {
    if (cashBoxes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد صندوق مهيأ في النظام لصرف المبلغ')),
      );
      return;
    }

    final amountController = TextEditingController(text: supplier.currentBalance.toStringAsFixed(2));
    final notesController = TextEditingController();
    int selectedBoxId = cashBoxes.first.id!;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.outbox_outlined, color: AppTheme.secondary),
              const SizedBox(width: 8),
              Text('سند صرف - ${supplier.name}'),
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
                    decoration: const InputDecoration(labelText: 'صندوق الدفع / الخزينة *'),
                    items: cashBoxes.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
                    onChanged: (v) => setDialogState(() => selectedBoxId = v!),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'المبلغ المصروف *', suffixText: 'ر.س'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(labelText: 'ملاحظات / سبب الصرف (اختياري)'),
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
                    const SnackBar(content: Text('يرجى إدخال مبلغ سداد صحيح')),
                  );
                  return;
                }

                await DatabaseHelper.instance.recordSupplierPayment(
                  supplierId: supplier.id!,
                  amount: amount,
                  cashBoxId: selectedBoxId,
                  notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                );

                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) Navigator.pop(context);
                _loadCreditors();

                // إشعار ومشاركة سند الصرف PDF
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
                      content: const Text('تم تسجيل سند الصرف وسداد دفعة المورد بنجاح!'),
                      backgroundColor: AppTheme.success,
                      action: SnackBarAction(
                        label: 'مشاركة السند PDF',
                        textColor: Colors.white,
                        onPressed: () {
                          PdfInvoiceService.sharePaymentReceiptPdf(
                            receiptType: 'سند صرف',
                            receiptNumber: 'PAY-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
                            partyName: supplier.name,
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
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondary),
              child: const Text('تأكيد الصرف'),
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
        title: const Text('مستحقات وذمم الموردين', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // بطاقة ملخص مستحقات الموردين
            Card(
              color: AppTheme.secondary,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('إجمالي المبالغ المستحقة للموردين',
                              style: TextStyle(color: Colors.white70, fontSize: 13)),
                          const SizedBox(height: 6),
                          Text(
                            Formatters.formatCurrency(_totalPayables),
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
                          const Icon(Icons.local_shipping_outlined, color: Colors.white, size: 24),
                          const SizedBox(height: 4),
                          Text('${_creditors.length} مورد دائن',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // حقل البحث
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'ابحث عن مورد دائن بالاسم أو الرمز أو الهاتف...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _loadCreditors();
                        },
                      )
                    : null,
              ),
              onChanged: (_) => _loadCreditors(),
            ),
            const SizedBox(height: 14),

            // قائمة الموردين الدائنين
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _creditors.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_outline, size: 64, color: AppTheme.success),
                              SizedBox(height: 12),
                              Text('رائع! تم سداد جميع مستحقات الموردين بالكامل',
                                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: _creditors.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final s = _creditors[index];
                            return Card(
                              child: ListTile(
                                onTap: () => _showSupplierDetailAndPayment(s),
                                leading: CircleAvatar(
                                  backgroundColor: AppTheme.secondary.withValues(alpha: 0.1),
                                  child: const Icon(Icons.local_shipping, color: AppTheme.secondary),
                                ),
                                title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                subtitle: Text('الرمز: ${s.code} | الهاتف: ${s.phone ?? "غير مسجل"}'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          Formatters.formatCurrency(s.currentBalance),
                                          style: const TextStyle(
                                            color: AppTheme.danger,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const Text('مستحق للمورد', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
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
