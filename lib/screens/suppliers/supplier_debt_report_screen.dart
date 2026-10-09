import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/database/database_helper.dart';
import '../../models/supplier_model.dart';

/// تقرير تفصيلي لذمم الموردين ومتابعة الحسابات الدائنة (المستحقات)
class SupplierDebtReportScreen extends StatefulWidget {
  const SupplierDebtReportScreen({super.key});

  @override
  State<SupplierDebtReportScreen> createState() => _SupplierDebtReportScreenState();
}

class _SupplierDebtReportScreenState extends State<SupplierDebtReportScreen> {
  List<SupplierModel> _suppliersWithPayables = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final suppliers = await DatabaseHelper.instance.getSuppliers();
    if (mounted) {
      setState(() {
        _suppliersWithPayables = suppliers.where((s) => s.hasPayables).toList();
        _isLoading = false;
      });
    }
  }

  Future<void> _printOrExportReport() async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();

    final totalPayables = _suppliersWithPayables.fold(0.0, (sum, s) => sum + s.currentBalance);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('تقرير ذمم ومستحقات الموردين (الحسابات الدائنة)', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  pw.Text('التاريخ: ${DateTime.now().toIso8601String().substring(0, 10)}', style: const pw.TextStyle(fontSize: 12)),
                ],
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(border: pw.Border.all()),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('عدد الموردين المستحق لهم: ${_suppliersWithPayables.length}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('إجمالي الذمم والمستحقات: ${Formatters.formatCurrency(totalPayables)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
            pw.TableHelper.fromTextArray(
              headers: ['كود المورد', 'اسم المورد', 'الهاتف', 'الرقم الضريبي', 'الرصيد المستحق (دائن)'],
              data: _suppliersWithPayables.map((s) {
                return [
                  s.code,
                  s.name,
                  s.phone ?? '-',
                  s.taxNumber ?? '-',
                  Formatters.formatCurrency(s.currentBalance),
                ];
              }).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
              cellAlignment: pw.Alignment.centerRight,
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    final totalPayables = _suppliersWithPayables.fold(0.0, (sum, s) => sum + s.currentBalance);

    return Scaffold(
      appBar: AppBar(
        title: const Text('تقرير ذمم ومستحقات الموردين'),
        actions: [
          if (!_isLoading && _suppliersWithPayables.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.print_outlined),
              tooltip: 'طباعة وتصدير PDF',
              onPressed: _printOrExportReport,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // بطاقة الملخص
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Theme.of(context).cardColor,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Text('عدد الموردين المستحق لهم', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                          const SizedBox(height: 4),
                          Text(
                            '${_suppliersWithPayables.length}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Container(height: 35, width: 1, color: Colors.grey.shade300),
                      Column(
                        children: [
                          const Text('إجمالي الذمم المستحقة', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                          const SizedBox(height: 4),
                          Text(
                            Formatters.formatCurrency(totalPayables),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.danger),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // جدول أو قائمة الذمم
                Expanded(
                  child: _suppliersWithPayables.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_outline, size: 64, color: AppTheme.success.withValues(alpha: 0.7)),
                              const SizedBox(height: 12),
                              const Text('لا توجد ذمم أو مستحقات متأخرة على أي مورد حالياً', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              const Text('جميع حسابات الموردين مسددة بالكامل', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _suppliersWithPayables.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final s = _suppliersWithPayables[index];
                            final percentOfTotal = totalPayables > 0 ? (s.currentBalance / totalPayables * 100).toStringAsFixed(1) : '0';

                            return Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppTheme.danger.withValues(alpha: 0.1),
                                  child: Text('${index + 1}', style: const TextStyle(color: AppTheme.danger, fontWeight: FontWeight.bold)),
                                ),
                                title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text(
                                  'الكود: ${s.code} ${s.phone != null ? "• هاتف: ${s.phone}" : ""}\nنسبة المستحق: $percentOfTotal% من الإجمالي',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: Text(
                                  Formatters.formatCurrency(s.currentBalance),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: AppTheme.danger,
                                  ),
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
