import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/invoice_model.dart';
import '../../models/invoice_item_model.dart';
import '../utils/formatters.dart';

/// خدمة توليد ومشاركة وطباعة فواتير المبيعات بصيغة PDF باللغة العربية (RTL)
class PdfInvoiceService {
  static pw.Font? _regularFont;
  static pw.Font? _boldFont;

  /// تحميل الخط العربي المعتمد من أصول التطبيق
  static Future<void> _loadFonts() async {
    if (_regularFont != null && _boldFont != null) return;
    try {
      final regData = await rootBundle.load('assets/fonts/IBMPlexSansArabic-Regular.ttf');
      final boldData = await rootBundle.load('assets/fonts/IBMPlexSansArabic-Bold.ttf');
      _regularFont = pw.Font.ttf(regData);
      _boldFont = pw.Font.ttf(boldData);
    } catch (_) {
      // في حال تعذر تحميل الخط من الأصول محلياً، يتم الرجوع لخط Cairo عبر مكتبة الطباعة
      _regularFont = await PdfGoogleFonts.cairoRegular();
      _boldFont = await PdfGoogleFonts.cairoBold();
    }
  }

  /// إنشاء مستند PDF لفاتورة المبيعات بتنسيق عربي واحترافي
  static Future<Uint8List> generateInvoicePdf({
    required InvoiceModel invoice,
    required List<InvoiceItemModel> items,
    required Map<String, String> shopSettings,
  }) async {
    await _loadFonts();

    final pdf = pw.Document();
    final shopName = shopSettings['shopName'] ?? 'المتجر المالي والمحاسبي';
    final shopPhone = shopSettings['shopPhone'] ?? '';
    final shopAddress = shopSettings['shopAddress'] ?? '';
    final shopTaxNumber = shopSettings['shopTaxNumber'] ?? '';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(
          base: _regularFont!,
          bold: _boldFont!,
        ),
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // 1. ترويسة المنشأة
                pw.Container(
                  padding: const pw.EdgeInsets.only(bottom: 12),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 1.5)),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            shopName,
                            style: pw.TextStyle(font: _boldFont, fontSize: 20, color: PdfColors.blue900),
                          ),
                          if (shopPhone.isNotEmpty)
                            pw.Text('هاتف: $shopPhone', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                          if (shopAddress.isNotEmpty)
                            pw.Text('العنوان: $shopAddress', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                          if (shopTaxNumber.isNotEmpty)
                            pw.Text('الرقم الضريبي: $shopTaxNumber', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                        ],
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.blue50,
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                          border: pw.Border.all(color: PdfColors.blue200),
                        ),
                        child: pw.Text(
                          invoice.type == 'sale' ? 'فاتورة مبيعات' : 'فاتورة مشتريات',
                          style: pw.TextStyle(font: _boldFont, fontSize: 16, color: PdfColors.blue900),
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 16),

                // 2. بيانات الفاتورة والعميل
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('رقم الفاتورة: ${invoice.invoiceNumber}', style: pw.TextStyle(font: _boldFont, fontSize: 11)),
                          pw.SizedBox(height: 4),
                          pw.Text('التاريخ: ${Formatters.formatDateTime(DateTime.parse(invoice.date))}', style: const pw.TextStyle(fontSize: 10)),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            invoice.type == 'sale'
                                ? 'العميل: ${invoice.customerName ?? "عميل نقدي عام"}'
                                : 'المورد: ${invoice.supplierName ?? invoice.customerName ?? "مورد عام"}',
                            style: pw.TextStyle(font: _boldFont, fontSize: 11),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text('طريقة الدفع: ${invoice.paymentMethod}', style: const pw.TextStyle(fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 16),

                // 3. جدول بنود الفاتورة
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                  columnWidths: const {
                    0: pw.FlexColumnWidth(3.5),
                    1: pw.FlexColumnWidth(1.2),
                    2: pw.FlexColumnWidth(1.5),
                    3: pw.FlexColumnWidth(1.8),
                  },
                  children: [
                    // سطر الترويسة
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                      children: [
                        _buildTableHeader('الصنف / البيان'),
                        _buildTableHeader('الكمية', align: pw.TextAlign.center),
                        _buildTableHeader('السعر', align: pw.TextAlign.center),
                        _buildTableHeader('الإجمالي', align: pw.TextAlign.left),
                      ],
                    ),
                    // أسطر البنود
                    ...items.map(
                      (item) => pw.TableRow(
                        children: [
                          _buildTableCell(item.productName),
                          _buildTableCell(Formatters.formatNumber(item.quantity), align: pw.TextAlign.center),
                          _buildTableCell(Formatters.formatNumber(item.unitPrice), align: pw.TextAlign.center),
                          _buildTableCell(Formatters.formatCurrency(item.total), align: pw.TextAlign.left, isBold: true),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 16),

                // 4. ملخص الأرقام المالية
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Container(
                      width: 240,
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey300),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                      ),
                      child: pw.Column(
                        children: [
                          _buildSummaryLine('الإجمالي قبل الخصم:', Formatters.formatCurrency(invoice.subtotal)),
                          if (invoice.discount > 0)
                            _buildSummaryLine('الخصم:', '- ${Formatters.formatCurrency(invoice.discount)}', color: PdfColors.red800),
                          pw.Divider(color: PdfColors.grey300),
                          _buildSummaryLine('صافي الفاتورة:', Formatters.formatCurrency(invoice.total), isBold: true, fontSize: 12, color: PdfColors.blue900),
                          _buildSummaryLine('المبلغ المدفوع:', Formatters.formatCurrency(invoice.paid)),
                          if (invoice.remaining > 0)
                            _buildSummaryLine('المتبقي (آجل):', Formatters.formatCurrency(invoice.remaining), isBold: true, color: PdfColors.red800),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 12),

                // 5. التفقيط المالي باللغة العربية
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue50,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    border: pw.Border.all(color: PdfColors.blue200, width: 0.5),
                  ),
                  child: pw.Text(
                    'المبلغ كتابةً: ${Formatters.tafqeet(invoice.total)}',
                    style: pw.TextStyle(font: _boldFont, fontSize: 11, color: PdfColors.blue900),
                    textAlign: pw.TextAlign.center,
                  ),
                ),

                if (invoice.notes != null && invoice.notes!.isNotEmpty) ...[
                  pw.SizedBox(height: 10),
                  pw.Text('ملاحظات: ${invoice.notes}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                ],

                pw.Spacer(),

                // 6. تذييل الفاتورة
                pw.Center(
                  child: pw.Text(
                    'شكرًا لتعاملكم معنا | تم استخراج الفاتورة عبر النظام المحاسبي',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  /// مشاركة ملف PDF مباشرة عبر نافذة المشاركة في النظام
  static Future<void> shareInvoicePdf({
    required InvoiceModel invoice,
    required List<InvoiceItemModel> items,
    required Map<String, String> shopSettings,
  }) async {
    final pdfBytes = await generateInvoicePdf(
      invoice: invoice,
      items: items,
      shopSettings: shopSettings,
    );
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'فاتورة_${invoice.invoiceNumber}.pdf',
    );
  }

  /// طباعة الفاتورة أو معاينتها للطباعة
  static Future<void> printInvoicePdf({
    required InvoiceModel invoice,
    required List<InvoiceItemModel> items,
    required Map<String, String> shopSettings,
  }) async {
    final pdfBytes = await generateInvoicePdf(
      invoice: invoice,
      items: items,
      shopSettings: shopSettings,
    );
    await Printing.layoutPdf(
      onLayout: (format) async => pdfBytes,
      name: 'فاتورة_${invoice.invoiceNumber}',
    );
  }

  /// إنشاء مستند PDF لسند القبض أو سند الصرف المالي
  static Future<Uint8List> generatePaymentReceiptPdf({
    required String receiptType,
    required String receiptNumber,
    required String partyName,
    required double amount,
    required String date,
    required String cashBoxName,
    String? notes,
    required Map<String, String> shopSettings,
  }) async {
    await _loadFonts();

    final pdf = pw.Document();
    final shopName = shopSettings['shopName'] ?? 'المتجر المالي والمحاسبي';
    final shopPhone = shopSettings['shopPhone'] ?? '';
    final shopAddress = shopSettings['shopAddress'] ?? '';
    final shopTaxNumber = shopSettings['shopTaxNumber'] ?? '';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(24),
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(
          base: _regularFont!,
          bold: _boldFont!,
        ),
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // ترويسة السند
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(shopName, style: pw.TextStyle(font: _boldFont, fontSize: 16, color: PdfColors.blue900)),
                        if (shopPhone.isNotEmpty)
                          pw.Text('هاتف: $shopPhone', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                        if (shopAddress.isNotEmpty)
                          pw.Text('العنوان: $shopAddress', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                        if (shopTaxNumber.isNotEmpty)
                          pw.Text('الرقم الضريبي: $shopTaxNumber', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: pw.BoxDecoration(
                        color: receiptType == 'سند قبض' ? PdfColors.green50 : PdfColors.amber50,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                        border: pw.Border.all(color: receiptType == 'سند قبض' ? PdfColors.green200 : PdfColors.amber200),
                      ),
                      child: pw.Text(
                        receiptType,
                        style: pw.TextStyle(
                          font: _boldFont,
                          fontSize: 14,
                          color: receiptType == 'سند قبض' ? PdfColors.green900 : PdfColors.amber900,
                        ),
                      ),
                    ),
                  ],
                ),
                pw.Divider(color: PdfColors.grey300, height: 16),

                // بيانات السند
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('رقم السند: $receiptNumber', style: pw.TextStyle(font: _boldFont, fontSize: 10)),
                      pw.Text('التاريخ: ${Formatters.formatDateTime(DateTime.tryParse(date) ?? DateTime.now())}', style: const pw.TextStyle(fontSize: 9.5)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 14),

                // الطرف والمبلغ
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _buildSummaryLine(receiptType == 'سند قبض' ? 'استلمنا من السيد/السادة:' : 'صرفنا إلى السيد/السادة:', partyName, isBold: true, fontSize: 11),
                      pw.SizedBox(height: 8),
                      _buildSummaryLine('المبلغ المستلم/المصروف:', Formatters.formatCurrency(amount), isBold: true, fontSize: 13, color: PdfColors.blue900),
                      pw.SizedBox(height: 6),
                      _buildSummaryLine('الحساب / الصندوق المالي:', cashBoxName, fontSize: 10),
                      if (notes != null && notes.isNotEmpty) ...[
                        pw.SizedBox(height: 6),
                        _buildSummaryLine('البيان / ملاحظات:', notes, fontSize: 10),
                      ],
                    ],
                  ),
                ),
                pw.SizedBox(height: 12),

                // التفقيط المالي
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue50,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    border: pw.Border.all(color: PdfColors.blue200, width: 0.5),
                  ),
                  child: pw.Text(
                    'المبلغ كتابةً: ${Formatters.tafqeet(amount)}',
                    style: pw.TextStyle(font: _boldFont, fontSize: 10, color: PdfColors.blue900),
                    textAlign: pw.TextAlign.center,
                  ),
                ),

                pw.Spacer(),

                // التوقيعات
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      children: [
                        pw.Text('توقيع المستلم', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                        pw.SizedBox(height: 24),
                        pw.Text('................................', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey500)),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.Text('توقيع المحاسب / الإدارة', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                        pw.SizedBox(height: 24),
                        pw.Text('................................', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey500)),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  /// مشاركة سند قبض أو صرف
  static Future<void> sharePaymentReceiptPdf({
    required String receiptType,
    required String receiptNumber,
    required String partyName,
    required double amount,
    required String date,
    required String cashBoxName,
    String? notes,
    required Map<String, String> shopSettings,
  }) async {
    final pdfBytes = await generatePaymentReceiptPdf(
      receiptType: receiptType,
      receiptNumber: receiptNumber,
      partyName: partyName,
      amount: amount,
      date: date,
      cashBoxName: cashBoxName,
      notes: notes,
      shopSettings: shopSettings,
    );
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: '${receiptType}_$receiptNumber.pdf',
    );
  }

  /// إنشاء كشف حساب مالي تفصيلي (عميل أو مورد) بصيغة PDF
  static Future<Uint8List> generateAccountStatementPdf({
    required String partyType,
    required String partyName,
    required String partyCode,
    required List<Map<String, dynamic>> statementEntries,
    required double finalBalance,
    required Map<String, String> shopSettings,
  }) async {
    await _loadFonts();

    final pdf = pw.Document();
    final shopName = shopSettings['shopName'] ?? 'المتجر المالي والمحاسبي';
    final shopPhone = shopSettings['shopPhone'] ?? '';
    final shopTaxNumber = shopSettings['shopTaxNumber'] ?? '';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(
          base: _regularFont!,
          bold: _boldFont!,
        ),
        header: (pw.Context context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(shopName, style: pw.TextStyle(font: _boldFont, fontSize: 18, color: PdfColors.blue900)),
                        if (shopPhone.isNotEmpty)
                          pw.Text('هاتف: $shopPhone', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                        if (shopTaxNumber.isNotEmpty)
                          pw.Text('الرقم الضريبي: $shopTaxNumber', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey100,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                        border: pw.Border.all(color: PdfColors.grey400),
                      ),
                      child: pw.Text(
                        'كشف حساب $partyType',
                        style: pw.TextStyle(font: _boldFont, fontSize: 16, color: PdfColors.grey900),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 12),
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey50,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    border: pw.Border.all(color: PdfColors.grey300),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('الاسم: $partyName ($partyCode)', style: pw.TextStyle(font: _boldFont, fontSize: 11)),
                      pw.Text('تاريخ الطباعة: ${Formatters.formatDate(DateTime.now())}', style: const pw.TextStyle(fontSize: 10)),
                      pw.Text('الرصيد النهائي: ${Formatters.formatCurrency(finalBalance)}',
                          style: pw.TextStyle(font: _boldFont, fontSize: 11, color: finalBalance > 0 ? PdfColors.red800 : PdfColors.green800)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 12),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          return [
            pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                columnWidths: const {
                  0: pw.FlexColumnWidth(2.0),
                  1: pw.FlexColumnWidth(2.0),
                  2: pw.FlexColumnWidth(2.5),
                  3: pw.FlexColumnWidth(1.8),
                  4: pw.FlexColumnWidth(1.8),
                  5: pw.FlexColumnWidth(2.0),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _buildTableHeader('التاريخ', align: pw.TextAlign.center),
                      _buildTableHeader('نوع الحركة', align: pw.TextAlign.center),
                      _buildTableHeader('رقم المرجع / البيان'),
                      _buildTableHeader('مدين', align: pw.TextAlign.left),
                      _buildTableHeader('دائن', align: pw.TextAlign.left),
                      _buildTableHeader('الرصيد', align: pw.TextAlign.left),
                    ],
                  ),
                  ...statementEntries.map((e) {
                    final dateStr = (e['date'] as String?)?.split('T').first ?? '';
                    final debit = (e['debit'] as num?)?.toDouble() ?? 0.0;
                    final credit = (e['credit'] as num?)?.toDouble() ?? 0.0;
                    final bal = (e['balance'] as num?)?.toDouble() ?? 0.0;
                    return pw.TableRow(
                      children: [
                        _buildTableCell(dateStr, align: pw.TextAlign.center),
                        _buildTableCell(e['type'] ?? '', align: pw.TextAlign.center),
                        _buildTableCell('${e['ref'] ?? ""} ${e['notes'] != null ? "(${e['notes']})" : ""}'),
                        _buildTableCell(debit > 0 ? Formatters.formatCurrency(debit) : '-', align: pw.TextAlign.left),
                        _buildTableCell(credit > 0 ? Formatters.formatCurrency(credit) : '-', align: pw.TextAlign.left),
                        _buildTableCell(Formatters.formatCurrency(bal), align: pw.TextAlign.left, isBold: true),
                      ],
                    );
                  }),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
            pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue50,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  border: pw.Border.all(color: PdfColors.blue200),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('صافي الرصيد المستحق: ${Formatters.formatCurrency(finalBalance)}',
                        style: pw.TextStyle(font: _boldFont, fontSize: 11, color: PdfColors.blue900)),
                    pw.Text(Formatters.tafqeet(finalBalance.abs()),
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
                  ],
                ),
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  /// مشاركة كشف الحساب المالي
  static Future<void> shareAccountStatementPdf({
    required String partyType,
    required String partyName,
    required String partyCode,
    required List<Map<String, dynamic>> statementEntries,
    required double finalBalance,
    required Map<String, String> shopSettings,
  }) async {
    final bytes = await generateAccountStatementPdf(
      partyType: partyType,
      partyName: partyName,
      partyCode: partyCode,
      statementEntries: statementEntries,
      finalBalance: finalBalance,
      shopSettings: shopSettings,
    );
    await Printing.sharePdf(bytes: bytes, filename: 'كشف_حساب_$partyCode.pdf');
  }

  static pw.Widget _buildTableHeader(String text, {pw.TextAlign align = pw.TextAlign.right}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(font: _boldFont, fontSize: 10, color: PdfColors.grey900),
        textAlign: align,
      ),
    );
  }

  static pw.Widget _buildTableCell(String text, {pw.TextAlign align = pw.TextAlign.right, bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(font: isBold ? _boldFont : _regularFont, fontSize: 9.5),
        textAlign: align,
      ),
    );
  }

  static pw.Widget _buildSummaryLine(String title, String value, {bool isBold = false, double fontSize = 10, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(title, style: pw.TextStyle(fontSize: fontSize, font: isBold ? _boldFont : _regularFont, color: color)),
          pw.Text(value, style: pw.TextStyle(fontSize: fontSize, font: isBold ? _boldFont : _regularFont, color: color)),
        ],
      ),
    );
  }
}
