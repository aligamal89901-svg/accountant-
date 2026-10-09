import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/constants/app_constants.dart';
import '../../data/database/database_helper.dart';
import '../../models/invoice_model.dart';
import '../../models/invoice_item_model.dart';
import '../../core/services/pdf_invoice_service.dart';

/// واجهة عرض فاتورة المبيعات الرسمية والطباعة والمشاركة (حسب البند 5 من المواصفات)
class InvoiceReceiptDialog extends StatefulWidget {
  final InvoiceModel invoice;
  final List<InvoiceItemModel>? items;

  const InvoiceReceiptDialog({
    super.key,
    required this.invoice,
    this.items,
  });

  static Future<void> show(BuildContext context, InvoiceModel invoice, [List<InvoiceItemModel>? items]) {
    return showDialog(
      context: context,
      builder: (ctx) => InvoiceReceiptDialog(invoice: invoice, items: items),
    );
  }

  @override
  State<InvoiceReceiptDialog> createState() => _InvoiceReceiptDialogState();
}

class _InvoiceReceiptDialogState extends State<InvoiceReceiptDialog> {
  String _shopName = AppConstants.defaultShopName;
  String _shopPhone = '';
  String _shopAddress = '';
  String _shopTaxNumber = '';
  List<InvoiceItemModel> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final name = await DatabaseHelper.instance.getSetting(AppConstants.keyShopName) ?? AppConstants.defaultShopName;
    final phone = await DatabaseHelper.instance.getSetting(AppConstants.keyShopPhone) ?? '';
    final address = await DatabaseHelper.instance.getSetting(AppConstants.keyShopAddress) ?? '';
    final tax = await DatabaseHelper.instance.getSetting(AppConstants.keyShopTaxNumber) ?? '';

    List<InvoiceItemModel> items = widget.items ?? [];
    if (items.isEmpty && widget.invoice.id != null) {
      items = await DatabaseHelper.instance.getInvoiceItems(widget.invoice.id!);
    }

    if (mounted) {
      setState(() {
        _shopName = name;
        _shopPhone = phone;
        _shopAddress = address;
        _shopTaxNumber = tax;
        _items = items;
        _isLoading = false;
      });
    }
  }

  String _generateShareableText() {
    final inv = widget.invoice;
    final buffer = StringBuffer();
    buffer.writeln('==============================');
    buffer.writeln(_shopName);
    if (_shopPhone.isNotEmpty) buffer.writeln('هاتف: $_shopPhone');
    if (_shopAddress.isNotEmpty) buffer.writeln('العنوان: $_shopAddress');
    if (_shopTaxNumber.isNotEmpty) buffer.writeln('الرقم الضريبي: $_shopTaxNumber');
    buffer.writeln('------------------------------');
    buffer.writeln('فاتورة ${inv.type == 'sale' ? 'مبيعات' : 'مشتريات'}: ${inv.invoiceNumber}');
    buffer.writeln('التاريخ: ${Formatters.formatDateTime(DateTime.parse(inv.date))}');
    buffer.writeln('العميل: ${inv.customerName ?? "عميل نقدي عام"}');
    buffer.writeln('طريقة الدفع: ${inv.paymentMethod}');
    buffer.writeln('------------------------------');
    buffer.writeln('البنود:');
    for (int i = 0; i < _items.length; i++) {
      final it = _items[i];
      buffer.writeln('${i + 1}. ${it.productName} | ${Formatters.formatNumber(it.quantity)} × ${Formatters.formatCurrency(it.unitPrice)} = ${Formatters.formatCurrency(it.total)}');
    }
    buffer.writeln('------------------------------');
    buffer.writeln('الإجمالي قبل الخصم: ${Formatters.formatCurrency(inv.subtotal)}');
    if (inv.discount > 0) buffer.writeln('الخصم: ${Formatters.formatCurrency(inv.discount)}');
    buffer.writeln('صافي الفاتورة: ${Formatters.formatCurrency(inv.total)}');
    buffer.writeln('المدفوع: ${Formatters.formatCurrency(inv.paid)}');
    if (inv.remaining > 0) buffer.writeln('المتبقي (آجل): ${Formatters.formatCurrency(inv.remaining)}');
    buffer.writeln('المبلغ كتابة: ${Formatters.tafqeet(inv.total)}');
    buffer.writeln('==============================');
    buffer.writeln('شكرًا لتعاملكم معنا!');
    return buffer.toString();
  }

  Map<String, String> get _shopSettingsMap => {
    'shopName': _shopName,
    'shopPhone': _shopPhone,
    'shopAddress': _shopAddress,
    'shopTaxNumber': _shopTaxNumber,
  };

  Future<void> _sharePdf() async {
    try {
      await PdfInvoiceService.shareInvoicePdf(
        invoice: widget.invoice,
        items: _items,
        shopSettings: _shopSettingsMap,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء مشاركة الفاتورة: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  Future<void> _printPdf() async {
    try {
      await PdfInvoiceService.printInvoicePdf(
        invoice: widget.invoice,
        items: _items,
        shopSettings: _shopSettingsMap,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء تجهيز الطباعة: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  Future<void> _cancelInvoice() async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد إلغاء الفاتورة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'تحذير: سيتم إلغاء الفاتورة محاسبياً وعكس أثرها بالكامل:\n'
              '• إعادة الكميات للمخزون تلقائياً.\n'
              '• استرجاع أي مبالغ مدفوعة من الصندوق.\n'
              '• تصفير أي ذمم متبقية مرتبطة بهذه الفاتورة.',
              style: TextStyle(fontSize: 13, color: AppTheme.danger),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'سبب الإلغاء (اختياري)',
                hintText: 'مثال: إرجاع بضاعة، خطأ إدخال',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('تراجع')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('تأكيد الإلغاء المحاسبي'),
          ),
        ],
      ),
    );

    if (confirmed == true && widget.invoice.id != null) {
      final success = await DatabaseHelper.instance.cancelInvoiceTransaction(
        widget.invoice.id!,
        reason: reasonController.text.trim().isEmpty ? null : reasonController.text.trim(),
      );
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم إلغاء الفاتورة وعكس أثرها المالي والمخزني بنجاح'), backgroundColor: AppTheme.success),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذر إلغاء الفاتورة'), backgroundColor: AppTheme.danger),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final inv = widget.invoice;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 520,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        padding: const EdgeInsets.all(20),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // شريط الإجراءات العلوي
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.receipt_long, color: AppTheme.primary, size: 26),
                          const SizedBox(width: 8),
                          Text(
                            inv.type == 'sale' ? 'فاتورة مبيعات' : 'فاتورة مشتريات',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          if (inv.status == 'ملغاة') ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.danger.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppTheme.danger),
                              ),
                              child: const Text('ملغاة', style: TextStyle(color: AppTheme.danger, fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          ],
                        ],
                      ),
                      Row(
                        children: [
                          if (inv.status != 'ملغاة' && inv.id != null)
                            IconButton(
                              icon: const Icon(Icons.cancel_outlined, color: AppTheme.danger, size: 22),
                              tooltip: 'إلغاء الفاتورة محاسبياً',
                              onPressed: _cancelInvoice,
                            ),
                          IconButton(
                            icon: const Icon(Icons.picture_as_pdf, color: AppTheme.danger, size: 22),
                            tooltip: 'مشاركة بصيغة PDF',
                            onPressed: _sharePdf,
                          ),
                          IconButton(
                            icon: const Icon(Icons.print_outlined, color: AppTheme.primary, size: 22),
                            tooltip: 'طباعة الفاتورة',
                            onPressed: _printPdf,
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy, size: 20),
                            tooltip: 'نسخ نص الفاتورة',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _generateShareableText()));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('تم نسخ نص الفاتورة إلى الحافظة')),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  // محتوى الفاتورة القابل للتمرير
                  Expanded(
                    child: SingleChildScrollView(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ترويسة الفاتورة
                            Center(
                              child: Column(
                                children: [
                                  Text(
                                    _shopName,
                                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primary),
                                  ),
                                  if (_shopPhone.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text('هاتف: $_shopPhone', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                  ],
                                  if (_shopAddress.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text('العنوان: $_shopAddress', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                  ],
                                  if (_shopTaxNumber.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text('الرقم الضريبي: $_shopTaxNumber', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Divider(thickness: 1),
                            // تفاصيل الفاتورة والعميل
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('رقم الفاتورة: ${inv.invoiceNumber}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text('التاريخ: ${Formatters.formatDateTime(DateTime.parse(inv.date))}', style: const TextStyle(fontSize: 12)),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('العميل: ${inv.customerName ?? "عميل نقدي عام"}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text('طريقة الدفع: ${inv.paymentMethod}', style: const TextStyle(fontSize: 12)),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // جدول البنود
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Table(
                                columnWidths: const {
                                  0: FlexColumnWidth(3),
                                  1: FlexColumnWidth(1.2),
                                  2: FlexColumnWidth(1.5),
                                  3: FlexColumnWidth(1.8),
                                },
                                children: [
                                  TableRow(
                                    decoration: BoxDecoration(color: AppTheme.surfaceVariant),
                                    children: const [
                                      Padding(padding: EdgeInsets.all(8.0), child: Text('الصنف', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                      Padding(padding: EdgeInsets.all(8.0), child: Text('الكمية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
                                      Padding(padding: EdgeInsets.all(8.0), child: Text('السعر', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
                                      Padding(padding: EdgeInsets.all(8.0), child: Text('الإجمالي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.end)),
                                    ],
                                  ),
                                  ..._items.map(
                                    (item) => TableRow(
                                      children: [
                                        Padding(padding: const EdgeInsets.all(8.0), child: Text(item.productName, style: const TextStyle(fontSize: 12))),
                                        Padding(padding: const EdgeInsets.all(8.0), child: Text(Formatters.formatNumber(item.quantity), style: const TextStyle(fontSize: 12), textAlign: TextAlign.center)),
                                        Padding(padding: const EdgeInsets.all(8.0), child: Text(Formatters.formatNumber(item.unitPrice), style: const TextStyle(fontSize: 12), textAlign: TextAlign.center)),
                                        Padding(padding: const EdgeInsets.all(8.0), child: Text(Formatters.formatCurrency(item.total), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.end)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            // ملخص المبالغ
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Column(
                                children: [
                                  _buildSummaryRow('الإجمالي قبل الخصم:', Formatters.formatCurrency(inv.subtotal)),
                                  if (inv.discount > 0)
                                    _buildSummaryRow('الخصم:', '- ${Formatters.formatCurrency(inv.discount)}', color: AppTheme.danger),
                                  const Divider(height: 12),
                                  _buildSummaryRow('صافي الفاتورة:', Formatters.formatCurrency(inv.total), isBold: true, fontSize: 15, color: AppTheme.primary),
                                  _buildSummaryRow('المدفوع:', Formatters.formatCurrency(inv.paid)),
                                  if (inv.remaining > 0)
                                    _buildSummaryRow('المتبقي (آجل):', Formatters.formatCurrency(inv.remaining), color: AppTheme.danger, isBold: true),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            // التفقيط المالي باللغة العربية
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'المبلغ كتابةً: ${Formatters.tafqeet(inv.total)}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            if (inv.notes != null && inv.notes!.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Text('ملاحظات: ${inv.notes}', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // أزرار العمليات
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _sharePdf,
                          icon: const Icon(Icons.picture_as_pdf_outlined, color: AppTheme.danger, size: 18),
                          label: const Text('مشاركة PDF'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _printPdf,
                          icon: const Icon(Icons.print_outlined, size: 18),
                          label: const Text('طباعة'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('تم'),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false, double fontSize = 13, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: fontSize, color: color ?? AppTheme.textSecondary, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(fontSize: fontSize, color: color, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}
