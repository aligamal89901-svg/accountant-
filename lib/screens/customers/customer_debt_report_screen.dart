import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/database/database_helper.dart';
import '../../models/customer_model.dart';

/// تقرير تفصيلي لذمم العملاء ومتابعة الحسابات المدينة
class CustomerDebtReportScreen extends StatefulWidget {
  const CustomerDebtReportScreen({super.key});

  @override
  State<CustomerDebtReportScreen> createState() => _CustomerDebtReportScreenState();
}

class _CustomerDebtReportScreenState extends State<CustomerDebtReportScreen> {
  List<CustomerModel> _debtors = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDebtors();
  }

  Future<void> _loadDebtors() async {
    setState(() => _isLoading = true);
    final customers = await DatabaseHelper.instance.getCustomers();
    if (mounted) {
      setState(() {
        _debtors = customers.where((c) => c.hasDebt).toList();
        _isLoading = false;
      });
    }
  }

  Future<void> _printOrExportReport() async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();

    final totalDebt = _debtors.fold(0.0, (sum, c) => sum + c.currentBalance);

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
                  pw.Text('تقرير ذمم وأرصدة العملاء المدينة', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
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
                  pw.Text('عدد العملاء المدينين: ${_debtors.length}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('إجمالي الذمم المستحقة: ${Formatters.formatCurrency(totalDebt)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
            pw.TableHelper.fromTextArray(
              headers: ['كود العميل', 'اسم العميل', 'الهاتف', 'سقف الائتمان', 'الرصيد المستحق (الذمة)'],
              data: _debtors.map((c) {
                return [
                  c.code,
                  c.name,
                  c.phone ?? '-',
                  c.creditLimit != null ? Formatters.formatCurrency(c.creditLimit!) : 'غير محدد',
                  Formatters.formatCurrency(c.currentBalance),
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
    final double totalDebt = _debtors.fold(0.0, (sum, c) => sum + c.currentBalance);

    return Scaffold(
      appBar: AppBar(
        title: const Text('تقرير ذمم العملاء'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'طباعة وتصدير التقرير PDF',
            onPressed: _debtors.isEmpty ? null : _printOrExportReport,
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
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      children: [
                        // ملخص التقرير
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('إجمالي الذمم المستحقة على العملاء:', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                                  const SizedBox(height: 4),
                                  Text(
                                    Formatters.formatCurrency(totalDebt),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppTheme.danger),
                                  ),
                                ],
                              ),
                              ElevatedButton.icon(
                                onPressed: _debtors.isEmpty ? null : _printOrExportReport,
                                icon: const Icon(Icons.print_outlined),
                                label: const Text('طباعة التقرير'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        _debtors.isEmpty
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(32),
                                  child: Text('رائع! لا توجد ذمم مستحقة على العملاء حالياً.', style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold)),
                                ),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _debtors.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 8),
                                itemBuilder: (ctx, i) {
                                  final customer = _debtors[i];
                                  final isOverLimit = customer.creditLimit != null && customer.currentBalance > customer.creditLimit!;

                                  return Container(
                                    decoration: AppTheme.cardDecoration(),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: (isOverLimit ? AppTheme.danger : AppTheme.primary).withValues(alpha: 0.1),
                                        child: Icon(Icons.person, color: isOverLimit ? AppTheme.danger : AppTheme.primary),
                                      ),
                                      title: Row(
                                        children: [
                                          Text(customer.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                          if (isOverLimit) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppTheme.danger.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Text('تجاوز السقف', style: TextStyle(color: AppTheme.danger, fontSize: 10, fontWeight: FontWeight.bold)),
                                            ),
                                          ],
                                        ],
                                      ),
                                      subtitle: Text(
                                        'كود: ${customer.code} | هاتف: ${customer.phone ?? "غير مسجل"} | سقف: ${customer.creditLimit != null ? Formatters.formatCurrency(customer.creditLimit!) : "غير محدد"}',
                                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                      ),
                                      trailing: Text(
                                        Formatters.formatCurrency(customer.currentBalance),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.danger),
                                      ),
                                    ),
                                  );
                                },
                              ),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
